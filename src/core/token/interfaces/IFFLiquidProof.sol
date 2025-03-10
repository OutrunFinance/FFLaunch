// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IERC20Errors.sol";

/**
 * @title FFLaunch Liquid Proof(POL) Token Interface
 */
interface IFFLiquidProof is IERC20, IERC20Errors {
    function launcher() external view returns (address);

    function initialize(
        string memory name, 
        string memory symbol, 
        uint8 decimals, 
        address launcher
    ) external;

    function mint(address _account, uint256 _amount) external;

    function burn(address account, uint256 value) external returns (bool);

    error PermissionDenied();

    error InsufficientBalance();
}