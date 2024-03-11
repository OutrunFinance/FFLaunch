//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

/**
 * @title IRETHStakeManager interface
 */
interface IRETHStakeManager {
    function stake(uint256 amountInRETH, uint256 lockupDays, address positionOwner, address receiver) external;
}