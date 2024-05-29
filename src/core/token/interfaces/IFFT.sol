// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IERC20Errors.sol";

/**
 * @title FF Token Standard Interface
 */
interface IFFT is IERC20, IERC20Errors {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function launcher() external view returns (address);

    function callee() external view returns (address);

    function balanceOf(address account) external view returns (uint256);

    function transferable() external view returns (bool);

    function enableTransfer() external;

    function mint(address _account, uint256 _amount) external;
}