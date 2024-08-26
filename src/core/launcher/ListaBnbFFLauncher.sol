// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IFFLauncher.sol";
import "../utils/AutoIncrementId.sol";
import "../external/OutrunAMMLibrary.sol";
import "../external/IOutrunAMMRouter.sol";
import "../external/IOutrunAMMPair.sol";
import "../external/IListaStakeManager.sol";
import "../external/INativeYieldTokenStakeManager.sol";
import "../generator/ITokenGenerator.sol";
import "../token/FFLiquidProof.sol";
import "../token/interfaces/IFFERC20.sol";
import "../token/interfaces/IFFLiquidProof.sol";

/**
 * @title ListaBnbFFLauncher
 */
contract ListaBnbFFLauncher is IFFLauncher, Ownable, AutoIncrementId {
    using SafeERC20 for IERC20;

    uint256 public constant DAY = 24 * 3600;
    uint256 public constant RATIO = 10000;
    address public immutable SLISBNB;
    address public immutable OSLISBNB;
    address public immutable LISTA_STAKE_MANAGER;
    address public immutable LISTA_BNB_STAKE_MANAGER;
    address public immutable OUTRUN_AMM_ROUTER;
    address public immutable OUTRUN_AMM_FACTORY;

    uint256 private _minDeposit;
    mapping(uint256 poolId => LaunchPool) private _launchPools;

    constructor(
        address _owner,
        address _slisBNB,
        address _oslisBNB,
        address _outrunAMMRouter,
        address _outrunAMMFactory,
        address _listaStakeManager,
        address _listaBNBStakeManager,
        uint256 minDeposit_
    ) Ownable(_owner) {
        SLISBNB = _slisBNB;
        OSLISBNB = _oslisBNB;
        OUTRUN_AMM_ROUTER = _outrunAMMRouter;
        OUTRUN_AMM_FACTORY = _outrunAMMFactory;
        LISTA_STAKE_MANAGER = _listaStakeManager;
        LISTA_BNB_STAKE_MANAGER = _listaBNBStakeManager;
        _minDeposit = minDeposit_;

        IERC20(OSLISBNB).approve(_outrunAMMRouter, type(uint256).max);
        IERC20(SLISBNB).approve(_listaBNBStakeManager, type(uint256).max);
    }

    function minDeposit() external view override returns (uint256) {
        return _minDeposit;
    }

    function launchPools(uint256 poolId) external view override returns (LaunchPool memory) {
        return _launchPools[poolId];
    }

    function setMinDeposit(uint256 minDeposit_) external override onlyOwner {
        _minDeposit = minDeposit_;
    }

    function _stakeAndMint(uint256 poolId, uint256 slisBNBAmount) internal {
        LaunchPool storage pool = _launchPools[poolId];
        uint256 currentTime = block.timestamp;
        uint64 startTime = pool.startTime;
        uint64 endTime = pool.endTime;
        uint128 lockupDays = pool.lockupDays;
        require(currentTime > startTime && currentTime < endTime, NotDepositStage(startTime, endTime));

        // stake native yield token
        address msgSender = msg.sender;
        (uint256 amountInPT,) = INativeYieldTokenStakeManager(LISTA_BNB_STAKE_MANAGER).stake(slisBNBAmount, lockupDays, msgSender, address(this), msgSender);

        // Calling the registered tokenGenerator contract to get liquidity token and mint token to user
        address generator = pool.generator;
        uint256 investorTokenAmount = ITokenGenerator(generator).generateInvestorToken(amountInPT, msgSender);
        uint256 liquidityTokenAmount = ITokenGenerator(generator).generateLiquidityToken(amountInPT);

        unchecked {
            uint256 mintedAmount = pool.mintedAmount + liquidityTokenAmount + investorTokenAmount;

            // if totalSupply == 0, indicates an unlimited amount of mintable tokens
            uint256 totalSupply = pool.totalSupply;
            if (totalSupply != 0) {
                uint256 mintableAmount = totalSupply * pool.sharePercent / RATIO;
                require(mintedAmount <= mintableAmount, InsufficientMintableAmount(mintableAmount));
            }
            pool.totalLiquidityFund += amountInPT;
            pool.mintedAmount = mintedAmount;
        }

        address token = pool.token;
        address router = OUTRUN_AMM_ROUTER;
        IERC20(token).approve(router, liquidityTokenAmount);
        (,, uint256 liquidity) = IOutrunAMMRouter(router).addLiquidity(
            OSLISBNB,
            token,
            amountInPT,
            liquidityTokenAmount,
            amountInPT,
            liquidityTokenAmount,
            address(this),
            block.timestamp + 600
        );
        IFFLiquidProof(pool.liquidProof).mint(msgSender, liquidity);
            
        emit StakeAndMint(poolId, msgSender, amountInPT, investorTokenAmount, liquidityTokenAmount, liquidity);
    }

    /**
     * @dev Deposit BNB and mint token
     */
    function depositFromNativeToken() external payable override{
        uint256 msgValue = msg.value;
        require(msgValue >= _minDeposit, InsufficientDepositAmount(msgValue));
        IListaStakeManager(LISTA_STAKE_MANAGER).deposit{value: msgValue}();

        _stakeAndMint(id, IERC20(SLISBNB).balanceOf(address(this)));
    }

    /**
     * @dev Deposit slisBNB and mint token
     * @param slisBNBAmount - Amount of slisBNB to deposit
     */
    function deposit(uint256 slisBNBAmount) external override {
        require(slisBNBAmount >= _minDeposit, InsufficientDepositAmount(_minDeposit));
        IERC20(SLISBNB).safeTransferFrom(msg.sender, address(this), slisBNBAmount);

        _stakeAndMint(id, slisBNBAmount);
    }

    /**
     * @dev Enable transfer about token of pool
     * @param poolId - LaunchPool id
     */
    function enablePoolTokenTransfer(uint256 poolId) external override {
        LaunchPool storage pool = _launchPools[poolId];
        address token = pool.token;
        uint256 endTime = pool.endTime;
        require(block.timestamp >= endTime, NotLiquidityLockStage(endTime));
        IFFERC20(token).enableTransfer();
    }

    /**
     * @dev Claim your liquidity by pooId when liquidity unlocked
     * @param poolId - LaunchPool id
     * @param claimedLiquidity - Claimed liquidity
     */
    function claimPoolLiquidity(uint256 poolId, uint256 claimedLiquidity) external override {
        address msgSender = msg.sender;
        LaunchPool storage pool = _launchPools[poolId];
        uint256 unlockTime = pool.endTime + pool.lockupDays * DAY;
        require(block.timestamp >= unlockTime, NotLiquidityUnlockStage(unlockTime));
        IFFLiquidProof(pool.liquidProof).burn(msgSender, claimedLiquidity);

        address pair = OutrunAMMLibrary.pairFor(OUTRUN_AMM_FACTORY, OSLISBNB, pool.token);
        IERC20(pair).safeTransfer(msgSender, claimedLiquidity);

        emit ClaimPoolLiquidity(poolId, msgSender, claimedLiquidity);
    }

    /**
     * @dev Claim transaction fees of liquidity pool
     * @param poolId - LaunchPool id
     * @param receiver - Address to receive transaction fees
     */
    function claimTransactionFees(uint256 poolId, address receiver) external override {
        require(receiver != address(0), ZeroAddress());
        address msgSender = msg.sender;
        LaunchPool storage pool = _launchPools[poolId];
        require(msgSender == pool.generator, PermissionDenied());
        uint256 endTime = pool.endTime;
        require(block.timestamp > endTime, NotLiquidityLockStage(endTime));

        address pairAddress = OutrunAMMLibrary.pairFor(OUTRUN_AMM_FACTORY, OSLISBNB, pool.token);
        IOutrunAMMPair pair = IOutrunAMMPair(pairAddress);
        (uint256 amount0, uint256 amount1) = pair.claimMakerFee();
        IERC20(pair.token0()).safeTransfer(receiver, amount0);
        IERC20(pair.token1()).safeTransfer(receiver, amount1);

        emit ClaimTransactionFees(poolId, receiver, amount0, amount1);
    }

    /**
     * @dev Generate remaining tokens after FFLaunch event
     * @param poolId - LaunchPool id
     * @notice Only generator can call, only can call once
     */
    function generateRemainingTokens(uint256 poolId) external override returns (uint256 remainingTokenAmount) {
        LaunchPool storage pool = _launchPools[poolId];
        uint256 sharePercent = pool.sharePercent;
        require(sharePercent < RATIO, InitialFullCirculation());
        require(!pool.areAllGenerated,  AlreadyGenerated());
        address msgSender = msg.sender;
        require(msgSender == pool.generator, PermissionDenied());
        uint256 generateTime = pool.endTime + (pool.lockupDays + 7) * DAY;
        require(block.timestamp >= generateTime, NotTokenGenerationStage(generateTime));

        pool.areAllGenerated = true;
        uint256 totalSupply = pool.totalSupply;
        uint256 mintedAmount = pool.mintedAmount;
        if (totalSupply == 0) {
            remainingTokenAmount = (RATIO - sharePercent) * mintedAmount / sharePercent;
        } else {
            remainingTokenAmount = totalSupply - mintedAmount;
        }

        address token = pool.token;
        address timeLockVault = pool.timeLockVault;
        IFFERC20(token).mint(timeLockVault, remainingTokenAmount);

        emit GenerateRemainingTokens(poolId, token, timeLockVault, remainingTokenAmount);
    }

    /**
     * @dev Register FF launchPool
     * @param poolParam - Pool param
     * @notice The tokenGenerator code should be kept as concise as possible and undergo auditing to prevent malicious behavior.
     */
    function registerPool(LaunchPool calldata poolParam) external override onlyOwner returns (uint256 poolId) {
        uint256 currentTime = block.timestamp;
        address token = poolParam.token;
        address timeLockVault = poolParam.timeLockVault;
        uint64 startTime = poolParam.startTime;
        uint64 endTime = poolParam.endTime;
        uint256 sharePercent = poolParam.sharePercent;
        require(
            token != address(0) && 
            timeLockVault != address(0) &&
            startTime > currentTime && 
            endTime > currentTime && 
            sharePercent > 0 && 
            sharePercent <= RATIO, 
            InvalidRegisterInfo()
        );

        address generator = poolParam.generator;
        ITokenGenerator tokenGenerator = ITokenGenerator(generator);
        require(tokenGenerator.token() == token && tokenGenerator.launcher() == address(this), InvalidTokenGenerator());

        uint256 currentPoolId = id;
        if (currentPoolId != 0) {
            require(currentTime > _launchPools[currentPoolId].endTime, LastPoolNotEnd());
        }

        FFLiquidProof liquidProof = new FFLiquidProof(
            string(abi.encodePacked(IFFERC20(token).name(), " Liquid")),
            string(abi.encodePacked(IFFERC20(token).symbol(), " LIQUID")),
            address(this)
        );
        LaunchPool memory pool = LaunchPool(
            token,
            generator,
            address(liquidProof),
            timeLockVault,
            0,
            startTime,
            endTime,
            poolParam.lockupDays,
            poolParam.totalSupply,
            sharePercent,
            0,
            false
        );
        poolId = nextId();
        _launchPools[poolId] = pool;

        emit RegisterPool(poolId, pool);
    }

    /**
     * @dev Update timeLockVault address
     * @param poolId - LaunchPool id
     * @param token - token address
     * @param timeLockVault - TimeLockVault contract address
     * @notice The address can only be updated after the TimeLockVault contract is reviewed by the Outrun audit team.
     */
    function updateTimeLockVault(uint256 poolId, address token, address timeLockVault) external override onlyOwner {
        LaunchPool storage pool = _launchPools[poolId];
        address poolToken = pool.token;
        require(poolToken == token, TokenMismatch(poolToken));
        uint256 unlockTime = pool.endTime + pool.lockupDays * DAY;
        require(block.timestamp <= unlockTime, TimeExceeded(unlockTime));
        pool.timeLockVault = timeLockVault;

        emit UpdateTimeLockVault(poolId, timeLockVault);
    }
}
