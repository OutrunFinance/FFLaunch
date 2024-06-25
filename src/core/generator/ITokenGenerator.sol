// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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
     * @param deployFundAmount - Amount of deployed fund
     */
    function generateLiquidityToken(uint256 deployFundAmount) external returns (uint256 liquidityTokenAmount);

    /**
     * @dev Generate the token when investor claim token
     * @param deployFundAmount Amount of deployed fund
     * @param receiver Investor address to receive the token
     * @notice MUST only FFLauncher can call this function
     */
    function generateInvestorToken(uint256 deployFundAmount, address receiver) external returns (uint256 investorTokenAmount);

    /**
     * @dev Generate remaining tokens after FFLaunch event
     * @param poolId Launch pool id
     */
    function generateRemainingTokens(uint256 poolId) external returns (uint256 remainingTokenAmount);

    /**
     * @dev Claim transaction fees through FFLauncher
     * @param receiver - Address to receive transaction fees
     */
    function claimTransactionFees(uint256 poolId, address receiver) external;
}