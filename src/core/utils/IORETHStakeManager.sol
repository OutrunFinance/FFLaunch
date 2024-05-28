//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

/**
 * @title IORETHStakeManager interface
 */
interface IORETHStakeManager {
    function stake(
        uint256 amountInORETH, 
        uint256 lockupDays, 
        address positionOwner, 
        address osETHTo, 
        address reyTo
    ) external returns (uint256, uint256);
}