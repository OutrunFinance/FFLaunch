// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IEthFFLauncher {
    struct LaunchPool {
        address token;
        address callee;
        uint16 lockupDays;
        uint16 deploySignal;
        uint48 startTime;
        uint48 endTime;
        uint128 mintFee;
        uint256 totalMintedCount;
        uint256 totalLP;
        uint256 totalREY;
        bool isClosed;
    }

    function launchPoolOf(uint256 poolId) external view returns (LaunchPool memory);

    function poolMintedCountsOf(uint256 poolId, address account) external view returns (uint256);

    function isPoolLPClaimedOf(uint256 poolId, address account) external view returns (bool);

    function checkMyPoolLP(uint256 poolId) external view returns (uint256);

    function mintFromPool(uint256 poolId) external payable;

    function registerPool(
        address token,
        address callee,
        uint16 lockupDays,
        uint16 deploySignal,
        uint48 startTime,
        uint48 endTime,
        uint128 mintFee
    ) external returns (uint256);

    event ClaimPoolLP(uint256 poolId, address account, uint256 lpAmount);

    event RegisterPool(uint256 indexed poolId, LaunchPool pool);
}