// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IFFLauncher.sol";
import "../utils/AutoIncrementId.sol";
import "../external/IORETH.sol";
import "../external/OutrunAMMLibrary.sol";
import "../external/IOutrunAMMRouter.sol";
import "../external/IOutrunAMMPair.sol";
import "../external/IStakeManager.sol";
import "../generator/ITokenGenerator.sol";
import "../token/FFLiquidProof.sol";
import "../token/interfaces/IFFERC20.sol";
import "../token/interfaces/IFFLiquidProof.sol";
import "../../blast/GasManagerable.sol";

/**
 * @title EthFFLauncher
 */
contract EthFFLauncher is IFFLauncher, Ownable, GasManagerable, AutoIncrementId {
    using SafeERC20 for IERC20;

    uint256 public constant DAY = 24 * 3600;
    uint256 public constant RATIO = 10000;
    address public immutable ORETH;
    address public immutable OSETH;
    address public immutable OUTRUN_AMM_ROUTER;
    address public immutable OUTRUN_AMM_FACTORY;
    address public immutable ORETH_STAKE_MANAGER;

    uint256 private _minDeposit;
    mapping(uint256 poolId => LaunchPool) private _launchPools;

    constructor(
        address _owner,
        address _orETH,
        address _osETH,
        address _gasManager,
        address _outrunAMMFactory,
        address _outrunAMMRouter,
        address _orETHStakeManager,
        uint256 minDeposit_
    ) Ownable(_owner) GasManagerable(_gasManager) {
        ORETH = _orETH;
        OSETH = _osETH;
        OUTRUN_AMM_ROUTER = _outrunAMMRouter;
        OUTRUN_AMM_FACTORY = _outrunAMMFactory;
        ORETH_STAKE_MANAGER = _orETHStakeManager;
        _minDeposit = minDeposit_;

        IERC20(ORETH).approve(_orETHStakeManager, type(uint256).max);
        IERC20(OSETH).approve(_outrunAMMRouter, type(uint256).max);
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

    /**
     * @dev Deposit ETH and mint token
     */
    function deposit() public payable {
        uint256 msgValue = msg.value;
        require(msgValue >= _minDeposit, InsufficientDepositAmount(_minDeposit));

        uint256 poolId = id;
        LaunchPool storage pool = _launchPools[poolId];
        uint256 currentTime = block.timestamp;
        uint64 startTime = pool.startTime;
        uint64 endTime = pool.endTime;
        uint128 lockupDays = pool.lockupDays;
        require(currentTime > startTime && currentTime < endTime, NotDepositStage(startTime, endTime));

        address msgSender = msg.sender;
        IORETH(ORETH).deposit{value: msgValue}();
        (uint256 amountInOSETH,) = IStakeManager(ORETH_STAKE_MANAGER).stake(msgValue, lockupDays, msgSender, address(this), msgSender);

        // Calling the registered tokenGenerator contract to get liquidity token and mint token to user
        address generator = pool.generator;
        uint256 investorTokenAmount = ITokenGenerator(generator).generateInvestorToken(amountInOSETH, msgSender);
        uint256 liquidityTokenAmount = ITokenGenerator(generator).generateLiquidityToken(amountInOSETH);

        unchecked {
            uint256 mintedAmount = pool.mintedAmount + liquidityTokenAmount + investorTokenAmount;            

            // if totalSupply == 0, indicates an unlimited amount of mintable tokens
            uint256 totalSupply = pool.totalSupply;
            if (totalSupply != 0) {
                uint256 mintableAmount = totalSupply * pool.sharePercent / RATIO;
                require(mintedAmount <= mintableAmount, InsufficientMintableAmount(mintableAmount));
            }
            pool.mintedAmount = mintedAmount;
            pool.totalLiquidityFund += amountInOSETH;
        }

        address token = pool.token;
        address router = OUTRUN_AMM_ROUTER;
        IERC20(token).approve(router, liquidityTokenAmount);
        (,, uint256 liquidity) = IOutrunAMMRouter(router).addLiquidity(
            OSETH,
            token,
            amountInOSETH,
            liquidityTokenAmount,
            amountInOSETH,
            liquidityTokenAmount,
            address(this),
            block.timestamp + 600
        );
        IFFLiquidProof(pool.liquidProof).mint(msgSender, liquidity);

        emit Deposit(poolId, msgSender, amountInOSETH, investorTokenAmount, liquidityTokenAmount, liquidity);
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

        address pair = OutrunAMMLibrary.pairFor(OUTRUN_AMM_FACTORY, pool.token, OSETH);
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

        address pairAddress = OutrunAMMLibrary.pairFor(OUTRUN_AMM_FACTORY, pool.token, OSETH);
        IOutrunAMMPair pair = IOutrunAMMPair(pairAddress);
        (uint256 amount0, uint256 amount1) = pair.claimMakerFee();
        address token0 = pair.token0();
        address token1 = pair.token1();
        IERC20(token0).safeTransfer(receiver, amount0);
        IERC20(token1).safeTransfer(receiver, amount1);

        emit ClaimTransactionFees(poolId, receiver, token0, amount0, token1, amount1);
    }

    /**
     * @dev Generate remaining tokens after FFLaunch event
     * @param poolId - LaunchPool id
     * @notice Only generator can call, only can call once
     */
    function generateRemainingTokens(uint256 poolId) external returns (uint256 remainingTokenAmount) {
        LaunchPool storage pool = _launchPools[poolId];
        uint256 sharePercent = pool.sharePercent;
        require(sharePercent < RATIO, InitialFullCirculation());
        require(!pool.areAllGenerated, AlreadyGenerated());
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
            address(this), 
            gasManager
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
     * @param token - Token address
     * @param timeLockVault - TimeLockVault contract address
     * @notice The address can only be updated after the TimeLockVault contract is reviewed by the Outrun audit team.
     */
    function updateTimeLockVault(uint256 poolId, address token, address timeLockVault) external override onlyOwner {
        require(timeLockVault != address(0), ZeroAddress());
        LaunchPool storage pool = _launchPools[poolId];
        address poolToken = pool.token;
        require(poolToken == token, TokenMismatch(poolToken));
        uint256 unlockTime = pool.endTime + pool.lockupDays * DAY;
        require(block.timestamp <= unlockTime, TimeExceeded(unlockTime));
        pool.timeLockVault = timeLockVault;

        emit UpdateTimeLockVault(poolId, timeLockVault);
    }

    receive() external payable {
        deposit();
    }
}
