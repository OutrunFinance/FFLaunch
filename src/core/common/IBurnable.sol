// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

 /**
  * @title Burnable interface
  */
interface IBurnable {
    /**
     * @notice Burn the token.
     * @param amount - The amount of the token to burn.
     */
	  function burn(uint256 amount) external;
}