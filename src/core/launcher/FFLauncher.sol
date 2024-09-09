// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IFFLauncher.sol";
import "../utils/AutoIncrementId.sol";
import "../token/FFLiquidProof.sol";
import "../token/interfaces/IFFERC20.sol";
import "../token/interfaces/IFFLiquidProof.sol";
import "../generator/ITokenGenerator.sol";
import "../../external/IOutrunAMMPair.sol";
import "../../external/IOutrunAMMRouter.sol";
import "../../external/OutrunAMMLibrary.sol";

/**
 * @title FFLauncher
 */
contract FFLauncher is IFFLauncher, Ownable, AutoIncrementId {
    using SafeERC20 for IERC20;

    uint256 public constant DAY = 24 * 3600;
    uint256 public constant RATIO = 10000;
    address public immutable UPT;
    address public immutable OUTRUN_AMM_ROUTER;
    address public immutable OUTRUN_AMM_FACTORY;

    mapping(uint256 poolId => LaunchPool) public launchPools;

    constructor(
        address _owner,
        address _upt,
        address _outrunAMMRouter,
        address _outrunAMMFactory
    ) Ownable(_owner) {
        UPT = _upt;
        OUTRUN_AMM_ROUTER = _outrunAMMRouter;
        OUTRUN_AMM_FACTORY = _outrunAMMFactory;

        IERC20(_upt).approve(_outrunAMMRouter, type(uint256).max);
    }

    function getPoolUnlockTime(uint256 poolId) external view override returns (uint256) {
        LaunchPool storage pool = launchPools[poolId];
        return pool.endTime + pool.lockupDays * DAY;
    }

    /**
     * @dev Deposit UPT and mint token
     * @param amountInUPT - Amount of UPT to deposit
     */
    function deposit(uint256 amountInUPT) external {
        address msgSender = msg.sender;
        IERC20(UPT).safeTransferFrom(msgSender, address(this), amountInUPT);
        LaunchPool storage pool = launchPools[id];
        uint256 currentTime = block.timestamp;
        uint128 startTime = pool.startTime;
        uint128 endTime = pool.endTime;
        require(currentTime > startTime && currentTime < endTime, NotDepositStage(startTime, endTime));

        // Calling the registered tokenGenerator contract to get liquidity token and mint token to user
        address generator = pool.generator;
        uint256 investorTokenAmount = ITokenGenerator(generator).generateInvestorToken(amountInUPT, msgSender);
        uint256 liquidityTokenAmount = ITokenGenerator(generator).generateLiquidityToken(amountInUPT);

        unchecked {
            uint256 mintedAmount = pool.mintedAmount + liquidityTokenAmount + investorTokenAmount;

            // if totalSupply == 0, indicates an unlimited amount of mintable tokens
            uint256 totalSupply = pool.totalSupply;
            if (totalSupply != 0) {
                uint256 mintableAmount = totalSupply * pool.sharePercent / RATIO;
                require(mintedAmount <= mintableAmount, InsufficientMintableAmount(mintableAmount));
            }
            pool.mintedAmount = mintedAmount;
        }

        address token = pool.token;
        address router = OUTRUN_AMM_ROUTER;
        IERC20(token).approve(router, liquidityTokenAmount);
        (,, uint256 liquidity) = IOutrunAMMRouter(router).addLiquidity(
            UPT,
            token,
            amountInUPT,
            liquidityTokenAmount,
            amountInUPT,
            liquidityTokenAmount,
            address(this),
            block.timestamp + 600
        );
        IFFLiquidProof(pool.liquidProof).mint(msgSender, liquidity);
            
        emit Deposit(id, msgSender, amountInUPT, investorTokenAmount, liquidityTokenAmount, liquidity);
    }

    /**
     * @dev Enable transfer about token of pool
     * @param poolId - LaunchPool id
     */
    function enablePoolTokenTransfer(uint256 poolId) external override {
        LaunchPool storage pool = launchPools[poolId];
        address token = pool.token;
        uint256 endTime = pool.endTime;
        require(block.timestamp >= endTime, NotLiquidityLockStage(endTime));
        IFFERC20(token).enableTransfer();
    }

    /**
     * @dev Redeem your liquidity by pooId when liquidity unlocked
     * @param poolId - LaunchPool id
     * @param liquidity - Claimed liquidity
     */
    function redeemLiquidity(uint256 poolId, uint256 liquidity) external override {
        address msgSender = msg.sender;
        LaunchPool storage pool = launchPools[poolId];
        uint256 unlockTime = pool.endTime + pool.lockupDays * DAY;
        require(block.timestamp >= unlockTime, NotLiquidityUnlockStage(unlockTime));
        IFFLiquidProof(pool.liquidProof).burn(msgSender, liquidity);

        address pair = OutrunAMMLibrary.pairFor(OUTRUN_AMM_FACTORY, UPT, pool.token);
        IERC20(pair).safeTransfer(msgSender, liquidity);

        emit RedeemLiquidity(poolId, msgSender, liquidity);
    }

    /**
     * @dev Claim trade fees of liquidity pool
     * @param poolId - LaunchPool id
     * @param receiver - Address to receive trade fees
     */
    function claimTradeFees(uint256 poolId, address receiver) external override {
        require(receiver != address(0), ZeroAddress());
        address msgSender = msg.sender;
        LaunchPool storage pool = launchPools[poolId];
        require(msgSender == pool.generator, PermissionDenied());
        uint256 endTime = pool.endTime;
        require(block.timestamp > endTime, NotLiquidityLockStage(endTime));

        address pairAddress = OutrunAMMLibrary.pairFor(OUTRUN_AMM_FACTORY, UPT, pool.token);
        IOutrunAMMPair pair = IOutrunAMMPair(pairAddress);
        (uint256 amount0, uint256 amount1) = pair.claimMakerFee();
        IERC20(pair.token0()).safeTransfer(receiver, amount0);
        IERC20(pair.token1()).safeTransfer(receiver, amount1);

        emit ClaimTradeFees(poolId, receiver, amount0, amount1);
    }

    /**
     * @dev Generate remaining tokens after FFLaunch event
     * @param poolId - LaunchPool id
     * @notice Only generator can call, only can call once
     */
    function generateRemainingTokens(uint256 poolId) external override returns (uint256 remainingTokenAmount) {
        LaunchPool storage pool = launchPools[poolId];
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
        uint128 startTime = poolParam.startTime;
        uint128 endTime = poolParam.endTime;
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
            require(currentTime > launchPools[currentPoolId].endTime, LastPoolNotEnd());
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
            startTime,
            endTime,
            poolParam.lockupDays,
            poolParam.totalSupply,
            sharePercent,
            0,
            false
        );
        poolId = nextId();
        launchPools[poolId] = pool;

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
        LaunchPool storage pool = launchPools[poolId];
        address poolToken = pool.token;
        require(poolToken == token, TokenMismatch(poolToken));
        uint256 unlockTime = pool.endTime + pool.lockupDays * DAY;
        require(block.timestamp <= unlockTime, TimeExceeded(unlockTime));
        pool.timeLockVault = timeLockVault;

        emit UpdateTimeLockVault(poolId, timeLockVault);
    }
}
