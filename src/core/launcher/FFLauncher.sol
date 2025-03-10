// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IBurnable} from "../common/IBurnable.sol";
import {IFFLauncher} from "./interfaces/IFFLauncher.sol";
import {FFLiquidProof} from "../token/FFLiquidProof.sol";
import {TokenHelper} from "../libraries/TokenHelper.sol";
import {IFFERC20} from "../token/interfaces/IFFERC20.sol";
import {IOutrunAMMPair} from "../common/IOutrunAMMPair.sol";
import {ITokenGenerator} from "../generator/ITokenGenerator.sol";
import {AutoIncrementId} from "../libraries/AutoIncrementId.sol";
import {IOutrunAMMRouter} from "../common/IOutrunAMMRouter.sol";
import {OutrunAMMLibrary} from "../libraries/OutrunAMMLibrary.sol";
import {IFFLiquidProof} from "../token/interfaces/IFFLiquidProof.sol";

/**
 * @title FFLauncher
 */
contract FFLauncher is IFFLauncher, TokenHelper, Pausable, Ownable, AutoIncrementId {
    using Clones for address;
    using SafeERC20 for IERC20;

    uint256 public constant DAY = 24 * 3600;
    uint256 public constant RATIO = 10000;
    uint256 public constant SWAP_FEERATE = 100;
    address public immutable UPT;
    address public immutable OUTRUN_AMM_ROUTER;
    address public immutable OUTRUN_AMM_FACTORY;

    address public polImplementation;

    mapping(uint256 poolId => LaunchPool) public launchPools;
    mapping(uint256 poolId => uint256) public claimableLiquidProofs;
    mapping(uint256 poolId => GenesisFund) public genesisFunds;
    mapping(uint256 poolId => uint256) public liquidProofLiquidities;
    mapping(uint256 poolId => mapping(address account => UserFundDetail)) public userFundDetails;

    constructor(
        address _owner,
        address _UPT,
        address _outrunAMMRouter,
        address _outrunAMMFactory,
        address _polImplementation
    ) Ownable(_owner) {
        UPT = _UPT;
        OUTRUN_AMM_ROUTER = _outrunAMMRouter;
        OUTRUN_AMM_FACTORY = _outrunAMMFactory;
        polImplementation = _polImplementation;

        _safeApproveInf(_UPT, _outrunAMMRouter);
    }

    /**
     * @dev Get the unlockTime of LaunchPool
     * @param poolId - LaunchPool id
     */
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
        require(currentStage >= Stage.Locked, NotReachedLockedStage(currentStage));

        uint256 totalFunds = genesisFunds[poolId].totalTokenFunds + genesisFunds[poolId].totalLiquidProofFunds;
        UserFundDetail storage userFundDetail = userFundDetails[poolId][msg.sender];
        unchecked {
            if (!userFundDetail.POLClaimStatus) claimableAmount = claimableLiquidProofs[poolId] * userFundDetail.totalFunds / totalFunds;
        }
    }

    /**
     * @dev Genesis launchPool by depositing UPT
     * @param amountInUPT - Amount of UPT to deposit
     * @param user - Address of user participating in the genesis
     */
    function genesis(uint256 amountInUPT, address user) external whenNotPaused override {
        LaunchPool storage pool = launchPools[id];
        Stage currentStage = pool.currentStage;
        require(currentStage == Stage.Genesis, NotGenesisStage(currentStage));
        
        _transferIn(UPT, msg.sender, amountInUPT);

        uint256 increasedTokenFund;
        uint256 increasedLiquidProofFund;
        unchecked {
            increasedLiquidProofFund = amountInUPT / 3;
            increasedTokenFund = amountInUPT - increasedLiquidProofFund;
        }

        GenesisFund storage genesisFund = genesisFunds[id];
        unchecked {
            genesisFund.totalTokenFunds  += uint128(increasedTokenFund);
            genesisFund.totalLiquidProofFunds += uint128(increasedLiquidProofFund);
            userFundDetails[id][user].totalFunds += amountInUPT;
        }

        // if totalSupply == 0, indicates an unlimited amount of mintable tokens
        uint256 totalSupply = pool.totalSupply;
        if (totalSupply != 0) {
            uint256 mintableAmount;
            unchecked {
                mintableAmount = totalSupply * pool.sharePercent / RATIO;
            }
            require(
                ITokenGenerator(pool.generator).previewGeneratePoolTokens(genesisFund.totalTokenFunds)
                    <= mintableAmount, 
                InsufficientMintableAmount(mintableAmount)
             );
        }

        emit Genesis(id, user, increasedTokenFund, increasedLiquidProofFund);
    }

    /**
     * @dev Adaptively change the LaunchPool stage
     * @param poolId - LaunchPool id
     */
    function changeStage(uint256 poolId) external whenNotPaused override returns (Stage currentStage) {
        LaunchPool storage pool = launchPools[id];
        uint256 currentTime = block.timestamp;
        uint128 startTime = pool.startTime;
        uint128 endTime = pool.endTime;
        require(startTime != 0 && currentTime > startTime, InThePreparationStage(startTime));
        
        uint256 unlockedTime = endTime + pool.lockupDays * DAY;
        if (pool.currentStage == Stage.Preparation && currentTime < endTime) {
            pool.currentStage = Stage.Genesis;
            currentStage = Stage.Genesis;
        } else if (pool.currentStage == Stage.Genesis && currentTime > endTime) {
            // Deploy FF token liquidity
            address token = pool.token;
            GenesisFund storage genesisFund = genesisFunds[poolId];
            uint128 totalTokenFunds = genesisFund.totalTokenFunds;
            uint256 tokenAmount = ITokenGenerator(pool.generator).generatePoolTokens(totalTokenFunds);
            pool.mintedAmount = uint128(tokenAmount);

            _safeApproveInf(UPT, OUTRUN_AMM_ROUTER);
            _safeApproveInf(token, OUTRUN_AMM_ROUTER);
            (,, uint256 tokenLiquidity) = IOutrunAMMRouter(OUTRUN_AMM_ROUTER).addLiquidity(
                token,
                UPT,
                tokenAmount,
                totalTokenFunds,
                tokenAmount,
                totalTokenFunds,
                address(this),
                block.timestamp
            );

            // Mint liquidity proof token and deploy liquid proof liquidity
            address liquidProof = pool.liquidProof;
            IFFLiquidProof(liquidProof).mint(address(this), tokenLiquidity);
            
            _safeApproveInf(UPT, OUTRUN_AMM_ROUTER);
            _safeApproveInf(liquidProof, OUTRUN_AMM_ROUTER);
            uint128 totalLiquidProofFunds = genesisFund.totalLiquidProofFunds;
            uint256 liquidProofAmount = tokenLiquidity / 4;
            (,, liquidProofLiquidities[poolId]) = IOutrunAMMRouter(OUTRUN_AMM_ROUTER).addLiquidity(
                liquidProof,
                UPT,
                liquidProofAmount,
                totalLiquidProofFunds,
                liquidProofAmount,
                totalLiquidProofFunds,
                address(this),
                block.timestamp
            );
            claimableLiquidProofs[poolId] = tokenLiquidity - liquidProofAmount;

            pool.currentStage = Stage.Locked;
            currentStage = Stage.Locked;
        } else if (pool.currentStage == Stage.Locked && currentTime > unlockedTime) {
            pool.currentStage = Stage.Unlocked;
            currentStage = Stage.Unlocked;
        } else if (pool.currentStage == Stage.Unlocked && currentTime > unlockedTime + 14 * DAY) {
            pool.currentStage = Stage.Remaining;
            currentStage = Stage.Remaining;
        }

        emit ChangeStage(poolId, currentStage);
    }

    /**
     * @dev Claim liquidProof in stage Locked
     * @param poolId - LaunchPool id
     */
    function claimLiquidProof(uint256 poolId) external whenNotPaused override returns (uint256 amount) {
        amount = claimableLiquidProof(poolId);

        if (amount != 0) {
            address msgSender = msg.sender;
            userFundDetails[poolId][msgSender].POLClaimStatus = true;
            _transferOut(launchPools[poolId].liquidProof, msgSender, amount);

            emit ClaimLiquidProof(poolId, msgSender, amount);
        }
    }

    /**
     * @dev Redeem liquidity of (liquidProof / UPT) pair
     * @param poolId - LaunchPool id
     */
    function redeemLiquidProofLiquidity(uint256 poolId) external whenNotPaused override returns (address pair, uint256 lpTokenAmount) {
        LaunchPool storage pool = launchPools[id];
        Stage currentStage = pool.currentStage;
        require(currentStage >= Stage.Unlocked, NotReachedUnlockedStage(currentStage));

        address msgSender = msg.sender;
        UserFundDetail storage userFundDetail = userFundDetails[poolId][msgSender];
        require(!userFundDetail.POLLiquidityClaimStatus, AlreadyRedeemed());
        
        userFundDetail.POLLiquidityClaimStatus = true;
        uint256 userTotalFunds = userFundDetail.totalFunds;
        uint256 totalFunds = genesisFunds[poolId].totalTokenFunds + genesisFunds[poolId].totalLiquidProofFunds;
        pair = OutrunAMMLibrary.pairFor(OUTRUN_AMM_FACTORY, pool.liquidProof, UPT, SWAP_FEERATE);
        unchecked {
            lpTokenAmount = _selfBalance(IERC20(pair)) * userTotalFunds / totalFunds;
        }
        _transferOut(pair, msgSender, lpTokenAmount);

        emit RedeemLiquidProofLiquidity(poolId, msgSender, pair, lpTokenAmount);
    }

    /**
     * @dev Redeem your liquidity by pooId when liquidity unlocked
     * @param poolId - LaunchPool id
     * @param amountInPOL - Burned POL token amount
     */
    function redeemLiquidity(uint256 poolId, uint256 amountInPOL) external whenNotPaused override {
        LaunchPool storage pool = launchPools[poolId];
        Stage currentStage = pool.currentStage;
        require(currentStage >= Stage.Unlocked, NotReachedUnlockedStage(currentStage));

        address msgSender = msg.sender;
        IFFLiquidProof(pool.liquidProof).burn(msgSender, amountInPOL);
        address pair = OutrunAMMLibrary.pairFor(OUTRUN_AMM_FACTORY, pool.token, UPT, SWAP_FEERATE);
        _transferOut(pair, msgSender, amountInPOL);

        emit RedeemLiquidity(poolId, msgSender, amountInPOL);
    }

    /**
     * @dev Claim maker fees of liquidity pool
     * @param poolId - LaunchPool id
     */
    function redeemMakerFees(uint256 poolId) external whenNotPaused override {
        LaunchPool storage pool = launchPools[poolId];
        Stage currentStage = pool.currentStage;
        require(currentStage >= Stage.Locked, NotReachedLockedStage(currentStage));

        address token = pool.token;
        IOutrunAMMPair tokenPair = IOutrunAMMPair(OutrunAMMLibrary.pairFor(OUTRUN_AMM_FACTORY, token, UPT, SWAP_FEERATE));
        (uint256 amount0, uint256 amount1) = tokenPair.claimMakerFee();
        uint256 UPTFee;
        uint256 tokenFee;
        if (amount0 != 0 && amount1 != 0) {
            address token0 = tokenPair.token0();
            UPTFee = token0 == UPT ? amount0 : amount1;
            tokenFee = token0 == token ? amount0 : amount1;
            address receiver = ITokenGenerator(pool.generator).fundReceiver();
            _transferOut(token, receiver, tokenFee);
            _transferOut(UPT, receiver, UPTFee);
        }
        
        address liquidProof = pool.liquidProof;
        IOutrunAMMPair liquidProofPair = IOutrunAMMPair(OutrunAMMLibrary.pairFor(OUTRUN_AMM_FACTORY, liquidProof, UPT, SWAP_FEERATE));
        (uint256 amount2, uint256 amount3) = liquidProofPair.claimMakerFee();
        uint256 burnedUPT;
        uint256 burnedLiquidProof;
        if (amount2 != 0 && amount3 != 0) {
            address token2 = tokenPair.token0();
            burnedUPT = token2 == UPT ? amount2 : amount3;
            burnedLiquidProof = token2 == liquidProof ? amount2 : amount3;
            IBurnable(UPT).burn(burnedUPT);
            IBurnable(liquidProof).burn(burnedLiquidProof);
        }
        emit RedeemMakerFees(poolId, UPTFee, tokenFee, burnedUPT, burnedLiquidProof);
    }

    /**
     * @dev Generate remaining tokens after FFLaunch event
     * @param poolId - LaunchPool id
     * @notice Only generator can call, only can call once
     */
    function generateRemainingTokens(uint256 poolId) external whenNotPaused override returns (uint256 remainingTokenAmount) {
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
    function registerPool(LaunchPool calldata poolParam) external whenNotPaused override onlyOwner returns (uint256 poolId) {
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

        address liquidProof = polImplementation.clone();
        IFFLiquidProof(liquidProof).initialize(
            string(abi.encodePacked("POL-", IFFERC20(token).name())),
            string(abi.encodePacked("POL-", IFFERC20(token).symbol())),
            18,
            address(this)
        );

        LaunchPool memory pool = LaunchPool(
            token,
            generator,
            liquidProof,
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
    function updateTimeLockVault(uint256 poolId, address token, address timeLockVault) external whenNotPaused override onlyOwner {
        LaunchPool storage pool = launchPools[poolId];
        address poolToken = pool.token;
        require(poolToken == token, TokenMismatch(poolToken));
        uint256 unlockTime = pool.endTime + pool.lockupDays * DAY;
        require(block.timestamp <= unlockTime, TimeExceeded(unlockTime));
        pool.timeLockVault = timeLockVault;

        emit UpdateTimeLockVault(poolId, timeLockVault);
    }

    /**
     * @dev Set POL implementation logic contract
     * @param _polImplementation - Address of polImplementation
     */
    function setPolImplementation(address _polImplementation) external override onlyOwner {
        require(_polImplementation != address(0), ZeroInput());

        polImplementation = _polImplementation;

        emit SetPolImplementation(_polImplementation);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
