// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IERC20Errors.sol";

/**
 * @title FF Token Standard Interface
 */
interface IFFT is IERC20, IERC20Errors {
    function launcher() external view returns (address);

    function generator() external view returns (address);

    function transferable() external view returns (bool);

    function enableTransfer() external;

    function mint(address _account, uint256 _amount) external;
}