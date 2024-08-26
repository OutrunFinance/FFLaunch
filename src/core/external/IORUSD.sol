// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

 /**
  * @title ORUSD interface
  */
interface IORUSD is IERC20 {
	function deposit(uint256 amount) external;

	function withdraw(uint256 amount) external;
}