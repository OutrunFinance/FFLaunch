// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @dev Custom pool callee 
 */
interface IPoolCallee {
    function token() external view returns (address);

    function launcher() external view returns (address);

    /**
     * @dev LP need to send to FFLauncher，PETH is the price token
     */  
    function deploy(address outswapRouter, uint256 deployFeeAmount) external returns (uint256);

    function mintTo(address to) external;
}