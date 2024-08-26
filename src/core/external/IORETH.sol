// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

 /**
  * @title ORETH interface
  */
interface IORETH is IERC20 {
    function deposit() payable external;

    function withdraw(uint256 amount) external;
}