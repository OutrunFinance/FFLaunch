// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IEthFFLauncher {
    struct LaunchPool {
        address token;
        address callee;
        uint64 startTime;
        uint64 endTime;
        uint128 mintFee;
        uint128 claimDeadline;
        uint128 lockupDays;
        uint128 totalActualFund;
        uint128 totalLP;
    }

    function launchPoolOf(uint256 poolId) external view returns (LaunchPool memory);

    function tempFundOf(uint256 poolId) external view returns (uint256);

    function tempFundPoolOf(uint256 poolId, address account) external view returns (uint256);

    function isPoolLPClaimedOf(uint256 poolId, address account) external view returns (bool);

    function checkMyPoolLP(uint256 poolId) external view returns (uint256);

    function deposit(uint256 poolId) external payable;

    function claimTokenOrFund(uint256 poolId) external;

    function registerPool(
        address token,
        address callee,
        uint64 startTime,
        uint64 endTime,
        uint128 mintFee,
        uint128 claimDeadline,
        uint128 lockupDays
    ) external returns (uint256);

    event ClaimPoolLP(uint256 poolId, address account, uint256 lpAmount);

    event RegisterPool(uint256 indexed poolId, LaunchPool pool);
}