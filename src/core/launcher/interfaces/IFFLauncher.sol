// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

/**
 * @title FFLauncher interface
 */
interface IFFLauncher {
    enum Stage {
        Preparation,
        Genesis,  
        Locked, 
        Unlocked,
        Remaining,
        Ended
    }

    struct LaunchPool {
        address token;                  // Token address
        address generator;              // Token generator address
        address liquidProof;            // Liquid proof token address
        address timeLockVault;          // Remaining tokens time lock vault
        uint128 startTime;              // StartTime of launchPool
        uint128 endTime;                // EndTime of launchPool
        uint256 lockupDays;             // LockupDay of liquidity
        uint128 totalSupply;            // Token totalSupply. if 0, The total supply is determined by the mintedAmount and the sharePercent.
        uint128 mintedAmount;           // Amount of minted tokens by LaunchPool, including tokens in the liquidity pool
        uint256 sharePercent;           // Percentage of totalSupply that can be minted by LaunchPool, if 100%, indicates can't generate remaining tokens
        Stage currentStage;             // Current stage
    }

    struct GenesisFund {
        uint128 totalTokenFunds;        // Initial fundraising(UPT) for token liquidity
        uint128 totalLiquidProofFunds;  // Initial fundraising(UPT) for liquidProof liquidity
    }

    struct UserFundDetail {
        uint256 totalFunds;             // Initial total fundraising(UPT)
        bool liquidProofClaimStatus;    // LiquidProof claim status
        bool proofLiquidityClaimStatus; // The liquidity of LiquidProof claim status
    }

    function getPoolUnlockTime(uint256 poolId) external view returns (uint256);

    function claimableLiquidProof(uint256 poolId) external view returns (uint256 claimableAmount);

    function genesis(uint256 amountInUPT) external;

    function changeStage(uint256 poolId) external returns (Stage currentStage);

    function claimLiquidProof(uint256 poolId) external returns (uint256 amount);

    function redeemLiquidProofLiquidity(uint256 poolId) external returns (address pair, uint256 lpTokenAmount);

    function redeemLiquidity(uint256 poolId, uint256 proofTokenAmount) external;

    function redeemMakerFees(uint256 poolId) external;

    function generateRemainingTokens(uint256 poolId) external returns (uint256 remainingTokenAmount);

    function registerPool(LaunchPool calldata poolParam) external returns (uint256 poolId);

    function updateTimeLockVault(uint256 poolId, address token, address timeLockVault) external;

    function setRevenuePool(address revenuePool) external;

    error ZeroInput();

    error LastPoolNotEnd();

    error AlreadyRedeemed();

    error PermissionDenied();

    error InvalidRegisterInfo();

    error InvalidTokenGenerator();

    error InitialFullCirculation();

    error TokenMismatch(address poolToken);

    error TimeExceeded(uint256 unlockTime);

    error NotLockedStage(Stage currentStage);

    error NotGenesisStage(Stage currentStage);
    
    error NotUnlockedStage(Stage currentStage);

    error NotRemainingStage(Stage currentStage);

    error InThePreparationStage(uint256 startTime);

    error InsufficientMintableAmount(uint256 mintableAmount);


    event Genesis(
        uint256 indexed poolId, 
        address indexed depositer, 
        uint256 increasedTokenFund, 
        uint256 increasedLiquidProofFund, 
        uint256 increasedTokenAmount
    );

    event ClaimLiquidProof(uint256 indexed poolId, address indexed receiver, uint256 amount);

    event RedeemLiquidProofLiquidity(
        uint256 indexed poolId, 
        address indexed receiver, 
        address indexed pair, 
        uint256 lpTokenAmount
    );

    event RedeemLiquidity(uint256 indexed poolId, address indexed receiver, uint256 liquidity);

    event RedeemMakerFees(
        uint256 indexed poolId, 
        address indexed receiver, 
        uint256 UPTFee, 
        uint256 tokenFee
    );

    event RedeemProtocolFees(
        uint256 indexed poolId, 
        address indexed revenuePool, 
        uint256 UPTProtocolFee, 
        uint256 liquidProofProtocolFee
    );

    event GenerateRemainingTokens(uint256 indexed poolId, address token, address timeLockVault, uint256 remainingTokenAmount);

    event RegisterPool(uint256 indexed poolId, LaunchPool pool);

    event UpdateTimeLockVault(uint256 indexed poolId, address timeLockVault);
}
