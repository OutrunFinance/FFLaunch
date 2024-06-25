// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title FFLauncher interface
 */
interface IFFLauncher {
    struct LaunchPool {
        address token;                  // Token address
        address generator;              // Token generator address
        address liquidityERC20;         // LiquidityERC20 address
        address timeLockVault;          // Remaining tokens time lock vault
        uint256 totalLiquidityFund;     // Funds(osETH|osUSD) actually added to the liquidity pool.
        uint128 maxDeposit;             // The maximum amount of funds that can be deposited each time.
        uint64 startTime;               // StartTime of launchPool
        uint64 endTime;                 // EndTime of launchPool
        uint256 lockupDays;             // LockupDay of liquidity
        uint256 totalSupply;            // Token totalSupply, if 0, indicates unlimited mintable tokens.
        uint256 sharePercent;           // Percentage of totalSupply that can be minted by LaunchPool, if 100%, indicates can't generate remaining tokens.
        uint256 mintedAmount;           // Amount of minted tokens by LaunchPool, including tokens in the liquidity pool.
        bool areAllGenerated;           // Are all tokens generated?
    }

    function launchPool(uint256 poolId) external view returns (LaunchPool memory);

    function tempFund(uint256 poolId) external view returns (uint256);

    function tempFundPool(uint256 poolId, address account) external view returns (uint256);


    function claimTokenOrFund(uint256 poolId) external;

    function enablePoolTokenTransfer(uint256 poolId) external;

    function claimPoolLiquidity(uint256 poolId, uint256 burnedLiquidity) external;

    function claimTransactionFees(uint256 poolId, address receiver) external;

    function generateRemainingTokens(uint256 poolId) external returns (uint256 remainingTokenAmount);

    function registerPool(LaunchPool calldata poolParam) external returns (uint256 poolId);

    function updateTimeLockVault(uint256 poolId, address token, address timeLockVault) external;


    event ClaimPoolLiquidity(uint256 indexed poolId, address indexed account, uint256 lpAmount);

    event ClaimTransactionFees(uint256 indexed poolId, address to, uint256 amount0, uint256 amount1);

    event GenerateRemainingTokens(uint256 indexed poolId, address token, address timeLockVault, uint256 remainingTokenAmount);

    event RegisterPool(uint256 indexed poolId, LaunchPool pool);

    event UpdateTimeLockVault(uint256 indexed poolId, address timeLockVault);
}