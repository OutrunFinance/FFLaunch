// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IERC20Errors.sol";

/**
 * @title FFLaunch Liquid Proof Token Interface
 */
interface IFFLiquidProof is IERC20, IERC20Errors {
    function launcher() external view returns (address);

    function mint(address _account, uint256 _amount) external;

    function burn(address account, uint256 value) external returns (bool);
}