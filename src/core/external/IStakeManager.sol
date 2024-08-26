//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

/**
 * @title StakeManager interface
 */
interface IStakeManager {
    function stake(
        uint256 stakedAmount, 
        uint256 lockupDays, 
        address positionOwner, 
        address ptRecipient, 
        address ytRecipient
    ) external returns (uint256 amountInPT, uint256 amountInYT);
}