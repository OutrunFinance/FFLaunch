// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IFFLauncher {
    struct LaunchPool {
        address token;
        uint256 mintLimit;
        uint64 lockupDays;
        uint64 deploySignal;
        uint64 mintFee;
        uint32 startTime;
        uint32 endTime;
        uint256 totalMintedCount;
    }

    function launchPoolOf(uint256 poolId) external view returns (LaunchPool memory);

    function poolCalleeOf(uint256 poolId) external view returns (address);

    function poolTotalLPsOf(uint256 poolId) external view returns (uint256);

    function poolMintedCountsOf(uint256 poolId, address account) external view returns (uint256);

    function checkMyPoolLP(uint256 poolId) external view returns (uint256);

    function mintFromPool(uint256 poolId) external payable;

    function registerPool(
        address token,
        uint256 mintLimit,
        uint64 lockupDays,
        uint64 deploySignal,
        uint64 mintFee,
        uint32 startTime,
        uint32 endTime
    ) external returns (uint256);

    function registerPoolCallee(uint256 poolId, address calleeAddr) external;

    event ClaimPoolLP(uint256 poolId, address account, uint256 lpAmount);

    event RegisterPool(uint256 indexed poolId, LaunchPool pool);

    event RegisterPoolCallee(uint256 indexed poolId, address calleeAddr);
}