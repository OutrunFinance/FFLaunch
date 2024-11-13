// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IFFLauncher.sol";
import "../token/FFLiquidProof.sol";
import "../token/interfaces/IFFERC20.sol";
import "../token/interfaces/IFFLiquidProof.sol";
import "../generator/ITokenGenerator.sol";
import "../libraries/AutoIncrementId.sol";
import "../libraries/TokenHelper.sol";
import "../libraries/IOutrunAMMPair.sol";
import "../libraries/IOutrunAMMRouter.sol";
import "../libraries/OutrunAMMLibrary.sol";

/**
 * @title FFLauncher
 */
contract FFLauncher is IFFLauncher, TokenHelper, Ownable, AutoIncrementId {
    using SafeERC20 for IERC20;

    uint256 public constant DAY = 24 * 3600;
    uint256 public constant RATIO = 10000;
    uint256 public constant SWAP_FEERATE = 100;
    address public immutable UPT;
    address public immutable OUTRUN_AMM_ROUTER;
    address public immutable OUTRUN_AMM_FACTORY;

    mapping(uint256 poolId => LaunchPool) public launchPools;
    mapping(uint256 poolId => uint256) public claimableLiquidProofs;
    mapping(uint256 poolId => GenesisFund) public genesisFunds;
    mapping(uint256 poolId => uint256) public liquidProofLiquidities;
    mapping(uint256 poolId => mapping(address account => UserFundDetail)) public userFundDetails;

    constructor(
        address _owner,
        address _UPT,
        address _outrunAMMRouter,
        address _outrunAMMFactory
    ) Ownable(_owner) {
        UPT = _UPT;
        OUTRUN_AMM_ROUTER = _outrunAMMRouter;
        OUTRUN_AMM_FACTORY = _outrunAMMFactory;

        _safeApproveInf(_UPT, _outrunAMMRouter);
    }

    function getPoolUnlockTime(uint256 poolId) external view override returns (uint256) {
        LaunchPool storage pool = launchPools[poolId];
        return pool.endTime + pool.lockupDays * DAY;
    }

    /**
     * @dev Preview claimable liquidProof of user in stage Locked
     * @param poolId - LaunchPool id
     */
    function claimableLiquidProof(uint256 poolId) public view override returns (uint256 claimableAmount) {
        LaunchPool storage pool = launchPools[poolId];
        Stage currentStage = pool.currentStage;
        require(currentStage == Stage.Locked, NotLockedStage(currentStage));

        uint256 totalFunds = genesisFunds[poolId].totalTokenFunds + genesisFunds[poolId].totalLiquidProofFunds;
        UserFundDetail storage userFundDetail = userFundDetails[poolId][msg.sender];
        uint256 userTotalFunds = userFundDetail.totalFunds;
        bool liquidProofClaimStatus = userFundDetail.liquidProofClaimStatus;
        if (liquidProofClaimStatus == true) {
            claimableAmount = 0;
        } else {
            claimableAmount = claimableLiquidProofs[poolId] * userTotalFunds / totalFunds;
        }
    }

    /**
     * @dev Deposit UPT and mint token
     * @param amountInUPT - Amount of UPT to deposit
     */
    function genesis(uint256 amountInUPT) external {
        LaunchPool storage pool = launchPools[id];
        Stage currentStage = pool.currentStage;
        require(currentStage == Stage.Genesis, NotGenesisStage(currentStage));
        
        address msgSender = msg.sender;
        _transferIn(UPT, msgSender, amountInUPT);

        // Calling the registered tokenGenerator contract to mint liquidity token
        uint256 increasedTokenFund;
        uint256 increasedLiquidProofFund;
        unchecked {
            increasedTokenFund = amountInUPT / 3;
            increasedLiquidProofFund = amountInUPT - increasedLiquidProofFund;
        }
        uint256 increasedTokenAmount = ITokenGenerator(pool.generator).generateLiquidityTokens(increasedTokenFund);

        uint256 mintedAmount = pool.mintedAmount + increasedTokenAmount;
        // if totalSupply == 0, indicates an unlimited amount of mintable tokens
        uint256 totalSupply = pool.totalSupply;
        if (totalSupply != 0) {
            uint256 mintableAmount = totalSupply * pool.sharePercent / RATIO;
            require(mintedAmount <= mintableAmount, InsufficientMintableAmount(mintableAmount));
        }
        pool.mintedAmount = uint128(mintedAmount);

        GenesisFund storage genesisFund = genesisFunds[id];
        unchecked {
            genesisFund.totalTokenFunds  += uint128(increasedTokenFund);
            genesisFund.totalLiquidProofFunds += uint128(increasedLiquidProofFund);
            userFundDetails[id][msgSender].totalFunds += amountInUPT;
        }

        emit Genesis(id, msgSender, increasedTokenFund, increasedLiquidProofFund, increasedTokenAmount);
    }

    /**
     * @dev Adaptively change the LaunchPool stage
     * @param poolId - LaunchPool id
     */
    function changeStage(uint256 poolId) external override returns (Stage currentStage) {
        LaunchPool storage pool = launchPools[id];
        uint256 currentTime = block.timestamp;
        uint128 startTime = pool.startTime;
        uint128 endTime = pool.endTime;
        require(currentTime < startTime, InThePreparationStage(startTime));
        
        uint256 unlockedTime = endTime + pool.lockupDays * DAY;
        if (pool.currentStage == Stage.Preparation && currentTime < endTime) {
            pool.currentStage = Stage.Genesis;
            currentStage = Stage.Genesis;
        } else if (pool.currentStage == Stage.Genesis && currentTime < unlockedTime) {
            // Deploy FF token liquidity
            address token = pool.token;
            GenesisFund storage genesisFund = genesisFunds[poolId];
            uint128 totalTokenFunds = genesisFund.totalTokenFunds;
            uint256 tokenLiquidityAmount = _selfBalance(IERC20(token));
            _safeApproveInf(token, OUTRUN_AMM_ROUTER);
            _safeApproveInf(UPT, OUTRUN_AMM_ROUTER);
            (,, uint256 tokenliquidity) = IOutrunAMMRouter(OUTRUN_AMM_ROUTER).addLiquidity(
                token,
                UPT,
                tokenLiquidityAmount,
                totalTokenFunds,
                tokenLiquidityAmount,
                totalTokenFunds,
                address(this),
                block.timestamp + 600
            );

            // Mint liquidity proof token and deploy liquid proof liquidity
            address liquidProof = pool.liquidProof;
            IFFLiquidProof(liquidProof).mint(address(this), tokenliquidity);
                
            _safeApproveInf(liquidProof, OUTRUN_AMM_ROUTER);
            _safeApproveInf(UPT, OUTRUN_AMM_ROUTER);
            uint128 totalLiquidProofFunds = genesisFund.totalLiquidProofFunds;
            uint256 liquidProofLiquidityAmount = tokenliquidity / 4;
            (,, liquidProofLiquidities[poolId]) = IOutrunAMMRouter(OUTRUN_AMM_ROUTER).addLiquidity(
                liquidProof,
                UPT,
                liquidProofLiquidityAmount,
                totalLiquidProofFunds,
                liquidProofLiquidityAmount,
                totalLiquidProofFunds,
                address(this),
                block.timestamp + 600
            );
            claimableLiquidProofs[poolId] = tokenliquidity - liquidProofLiquidityAmount;

            pool.currentStage = Stage.Locked;
            currentStage = Stage.Locked;
        } else if (pool.currentStage == Stage.Locked && currentTime > unlockedTime) {
            pool.currentStage = Stage.Unlocked;
            currentStage = Stage.Unlocked;
        } else if (pool.currentStage == Stage.Unlocked && currentTime > unlockedTime + 14 * DAY) {
            pool.currentStage = Stage.Remaining;
            currentStage = Stage.Remaining;
        }
    }

    /**
     * @dev Claim liquidProof in stage Locked
     * @param poolId - LaunchPool id
     */
    function claimLiquidProof(uint256 poolId) external returns (uint256 amount) {
        amount = claimableLiquidProof(poolId);

        if (amount != 0) {
            address msgSender = msg.sender;
            userFundDetails[poolId][msgSender].liquidProofClaimStatus = true;
            _transferOut(launchPools[poolId].liquidProof, msgSender, amount);

            emit ClaimLiquidProof(poolId, msgSender, amount);
        }
    }

    /**
     * @dev Redeem liquidity of (liquidProof / UPT) pair
     * @param poolId - LaunchPool id
     */
    function redeemLiquidProofLiquidity(uint256 poolId) external returns (address pair, uint256 lpTokenAmount) {
        LaunchPool storage pool = launchPools[id];
        Stage currentStage = pool.currentStage;
        require(currentStage == Stage.Unlocked, NotUnlockedStage(currentStage));

        address msgSender = msg.sender;
        UserFundDetail storage userFundDetail = userFundDetails[poolId][msgSender];
        require(!userFundDetail.proofLiquidityClaimStatus, AlreadyRedeemed());
        
        userFundDetail.proofLiquidityClaimStatus = true;
        uint256 userTotalFunds = userFundDetail.totalFunds;
        uint256 totalFunds = genesisFunds[poolId].totalTokenFunds + genesisFunds[poolId].totalLiquidProofFunds;
        pair = OutrunAMMLibrary.pairFor(OUTRUN_AMM_FACTORY, pool.liquidProof, UPT, SWAP_FEERATE);
        lpTokenAmount = _selfBalance(IERC20(pair)) * userTotalFunds / totalFunds;
        _transferOut(pair, msgSender, lpTokenAmount);

        emit RedeemLiquidProofLiquidity(poolId, msgSender, pair, lpTokenAmount);
    }

    /**
     * @dev Redeem your liquidity by pooId when liquidity unlocked
     * @param poolId - LaunchPool id
     * @param proofTokenAmount - Burned liquid proof token amount
     */
    function redeemLiquidity(uint256 poolId, uint256 proofTokenAmount) external override {
        LaunchPool storage pool = launchPools[poolId];
        Stage currentStage = pool.currentStage;
        require(currentStage == Stage.Unlocked, NotUnlockedStage(currentStage));

        address msgSender = msg.sender;
        IFFLiquidProof(pool.liquidProof).burn(msgSender, proofTokenAmount);
        address pair = OutrunAMMLibrary.pairFor(OUTRUN_AMM_FACTORY, pool.token, UPT, SWAP_FEERATE);
        _transferOut(pair, msgSender, proofTokenAmount);

        emit RedeemLiquidity(poolId, msgSender, proofTokenAmount);
    }

    /**
     * @dev Claim maker fees of liquidity pool
     * @param poolId - LaunchPool id
     * @param receiver - Address to receive trade fees
     */
    function redeemMakerFees(uint256 poolId, address receiver) external override returns (uint256 UPTFee, uint256 tokenFee) {
        require(receiver != address(0), ZeroAddress());
        address msgSender = msg.sender;
        LaunchPool storage pool = launchPools[poolId];
        require(msgSender == pool.generator, PermissionDenied());
        Stage currentStage = pool.currentStage;
        require(currentStage == Stage.Locked, NotLockedStage(currentStage));

        address token = pool.token;
        IOutrunAMMPair pair = IOutrunAMMPair(OutrunAMMLibrary.pairFor(OUTRUN_AMM_FACTORY, token, UPT, SWAP_FEERATE));

        (uint256 amount0, uint256 amount1) = pair.claimMakerFee();
        if (amount0 == 0 && amount1 == 0) return (0, 0);

        address token0 = pair.token0();
        UPTFee = token0 == UPT ? amount0 : amount1;
        tokenFee = token0 == token ? amount0 : amount1;
        _transferOut(token, receiver, tokenFee);
        _transferOut(UPT, receiver, UPTFee);

        emit RedeemMakerFees(poolId, receiver, UPTFee, tokenFee);
    }

    /**
     * @dev Generate remaining tokens after FFLaunch event
     * @param poolId - LaunchPool id
     * @notice Only generator can call, only can call once
     */
    function generateRemainingTokens(uint256 poolId) external override returns (uint256 remainingTokenAmount) {
        LaunchPool storage pool = launchPools[poolId];
        require(msg.sender == pool.generator, PermissionDenied());
        Stage currentStage = pool.currentStage;
        require(currentStage == Stage.Remaining, NotRemainingStage(currentStage));
        uint256 sharePercent = pool.sharePercent;
        require(sharePercent < RATIO, InitialFullCirculation());
        
        pool.currentStage == Stage.Ended;

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
            endTime > startTime &&
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
            18,
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
            0,
            sharePercent,
            Stage.Preparation
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
