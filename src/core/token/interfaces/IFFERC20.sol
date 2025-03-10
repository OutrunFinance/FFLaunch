// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IERC20Errors.sol";

/**
 * @title Fair&Free ERC20 Token Standard Interface
 */
interface IFFERC20 is IERC20, IERC20Errors {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function generator() external view returns (address);

    function mint(address account, uint256 amount) external;

    function burn(uint256 value) external;


    error PermissionDenied();

    error InsufficientBalance();
}