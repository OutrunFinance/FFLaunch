//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

/**
 * @title IORUSDStakeManager interface
 */
interface IORUSDStakeManager {
    function stake(
        uint256 amountInORUSD, 
        uint256 lockupDays, 
        address positionOwner, 
        address osUSDTo, 
        address ruyTo
    ) external returns (uint256 amountInOSUSD, uint256 amountInRUY);
}