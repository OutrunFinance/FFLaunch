// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @dev Custom pool callee 
 */
interface IPoolCallee {
    function token() external view returns (address);

    function launcher() external view returns (address);

    /**
     * @dev Get deployed token, send to FFLauncher, Only FFLauncher can call this function
     * @param deployFundAmount Amount of deployed fund
     */
    function getDeployedToken(uint256 deployFundAmount) external returns (uint256);

    /**
     * @dev Claim the token, only FFLauncher can call this function
     * @param deployFundAmount Amount of deployed fund
     * @param receiver Investor address to receive the token
     */
    function claim(uint256 deployFundAmount, address receiver) external;

    /**
     * @dev Claim maker fee by FFLauncher
     * @param receiver Address to receive maker fee
     */
    function claimMakerFee(uint256 poolId, address receiver) external;
}