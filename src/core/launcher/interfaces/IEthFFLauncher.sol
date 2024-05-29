// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IEthFFLauncher {
    struct LaunchPool {
        address token;
        address callee;
        uint128 claimDeadline;
        uint128 lockupDays;
        uint128 totalActualFund;
        uint128 totalLP;
        uint128 maxDeposit;
        uint64 startTime;
        uint64 endTime;
    }

    function tempFund(uint256 poolId) external view returns (uint256);

    function launchPool(uint256 poolId) external view returns (LaunchPool memory);

    function tempFundPool(uint256 poolId, address account) external view returns (uint256);

    function isPoolLPClaimed(uint256 poolId, address account) external view returns (bool);

    function viewMyPoolLP(uint256 poolId) external view returns (uint256);

    function deposit() external payable;

    function claimTokenOrFund(uint256 poolId) external;

    function enablePoolTokenTransfer(uint256 poolId) external;

    function claimPoolLP(uint256 poolId) external;

    function claimPoolMakerFee(uint256 poolId, address receiver) external;

    function registerPool(
        address token,
        address callee,
        uint64 startTime,
        uint64 endTime,
        uint128 mintFee,
        uint128 claimDeadline,
        uint128 lockupDays
    ) external returns (uint256 poolId);

    event ClaimPoolLP(uint256 indexed poolId, address account, uint256 lpAmount);

    event ClaimPoolMakerFee(uint256 indexed poolId, address to, uint256 makerFee);

    event RegisterPool(uint256 indexed poolId, LaunchPool pool);
}