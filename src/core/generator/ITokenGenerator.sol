// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

/**
 * @dev Custom Token Generator
 */
interface ITokenGenerator {
    /**
     * @dev FF token address
     */
    function token() external view returns (address);

    /**
     * @dev FFLauncher address
     */
    function launcher() external view returns (address);

    /**
     * @dev Generate the tokens to be added to the liquidity pool
     * @param liquidityFundAmount - Amount of liquidity fund
     */
    function generateLiquidityTokens(uint256 liquidityFundAmount) external returns (uint256 increasedTokenFund);
    
    /**
     * @dev Generate remaining tokens after FFLaunch event
     * @param poolId Launch pool id
     */
    function generateRemainingTokens(uint256 poolId) external returns (uint256 remainingTokenAmount);

    /**
     * @dev Redeem maker fees through FFLauncher
     * @param receiver - Address to receive Maker fees
     */
    function redeemMakerFees(uint256 poolId, address receiver) external;

    error PermissionDenied();
}