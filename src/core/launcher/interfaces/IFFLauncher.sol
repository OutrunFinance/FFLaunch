// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title FFLauncher interface
 */
interface IFFLauncher {
    struct LaunchPool {
        address token;              // Token address
        address generator;          // Token generator address
        address vault;              // Remaining tokens vault
        uint128 claimDeadline;      // Deadline of claim token
        uint128 lockupDays;         // LockupDay of liquidity
        uint128 totalLiquidityFund; // Funds(osETH|osUSD) actually added to the liquidity pool.
        uint128 totalLiquidityLP;   // Total liquidity of LP
        uint128 maxDeposit;         // The maximum amount of funds that can be deposited each time.
        uint64 startTime;           // StartTime of launchpool
        uint64 endTime;             // EndTime of launchpool
        uint256 totalSupply;        // Token totalSupply, if 0, indicates unlimited mintable tokens.
        uint256 sharePercent;       // Percentage of totalSupply that can be minted by LaunchPool, if 100%, indicates can't generate remaining tokens.
        uint256 mintedAmount;       // Amount of minted tokens by LaunchPool, including tokens in the liquidity pool.
        bool areAllGenerated;        // Are all tokens generated?
    }

    function launchPool(uint256 poolId) external view returns (LaunchPool memory);

    function tempFund(uint256 poolId) external view returns (uint256);

    function tempFundPool(uint256 poolId, address account) external view returns (uint256);

    function poolFunds(uint256 poolId, address account) external view returns (uint256);

    function isPoolLiquidityClaimed(uint256 poolId, address account) external view returns (bool);

    function viewPoolLiquidity(uint256 poolId) external view returns (uint256);


    function claimTokenOrFund(uint256 poolId) external;

    function enablePoolTokenTransfer(uint256 poolId) external;

    function claimPoolLiquidity(uint256 poolId) external;

    function claimTransactionFees(uint256 poolId, address receiver) external;

    function generateRemainingTokens(uint256 poolId) external returns (uint256 remainingTokenAmount);

    function registerPool(LaunchPool calldata poolParam) external returns (uint256 poolId);


    event ClaimPoolLiquidity(uint256 indexed poolId, address indexed account, uint256 lpAmount);

    event ClaimTransactionFees(uint256 indexed poolId, address to, uint256 feeLp);

    event RegisterPool(uint256 indexed poolId, LaunchPool pool);

    event GenerateRemainingTokens(uint256 indexed poolId, address token, address vault, uint256 remainingTokenAmount);
}