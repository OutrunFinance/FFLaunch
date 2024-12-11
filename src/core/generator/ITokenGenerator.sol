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
     * @dev Fund receiver address
     */
    function fundReceiver() external view returns (address);

    /**
     * @dev Preview generated tokens to be added to the liquidity pool
     * @param tokenFundAmount - Amount of token liquidity fund
     */
    function previewGenerateLiquidityTokens(uint256 tokenFundAmount) external view returns (uint256 generatedTokenAmount);

    /**
     * @dev Generate the tokens to be added to the liquidity pool
     * @param tokenFundAmount - Amount of token liquidity fund
     */
    function generateLiquidityTokens(uint256 tokenFundAmount) external returns (uint256 generatedTokenAmount);
    
    /**
     * @dev Generate remaining tokens after FFLaunch event
     * @param poolId Launch pool id
     */
    function generateRemainingTokens(uint256 poolId) external returns (uint256 remainingTokenAmount);

    /**
     * @dev Set fund receiver
     * @param fundReceiver - Address to receive maker fees
     */
    function setFundReceiver(address fundReceiver) external;

    /**
     * @dev Redeem Maker Fees
     * @param poolId - LaunchPool id
     */
    function redeemMakerFees(uint256 poolId) external;

    error PermissionDenied();
}