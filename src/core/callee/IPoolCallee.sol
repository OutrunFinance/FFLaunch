// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @dev Custom pool callee 
 */
interface IPoolCallee {
    function token() external view returns (address);

    function launcher() external view returns (address);

    /**
     * @dev LP need to send to FFLauncher
     */  
    function deploy(address outswapRouter, uint256 deployFundAmount) external returns (uint256);

    function claim(uint256 fund, address receiver) external;
}