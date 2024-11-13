// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../core/generator/ITokenGenerator.sol";
import "../core/libraries/Initializable.sol";
import "../core/token/interfaces/IFFERC20.sol";
import "../core/launcher/interfaces/IFFLauncher.sol";

/**
 * @dev example - $FF generator
 */
contract FFGenerator is ITokenGenerator, Ownable, Initializable {
    address public immutable LAUNCHER;
    uint256 public constant FUND_BASED_AMOUNT = 10000;

    address public token;
    address public fundReceiver;

    modifier onlyLauncher() {
        require(msg.sender == LAUNCHER, PermissionDenied());
        _;
    }

    constructor(address _owner, address _launcher, address _fundReceiver) Ownable(_owner) {
        LAUNCHER = _launcher;
        fundReceiver = _fundReceiver;
    }

    function launcher() external view override returns (address) {
        return LAUNCHER;
    }

    function initialize(address tokenAddress) external initializer onlyOwner {
        token = tokenAddress;
    } 

    /**
     * @dev Generate the tokens to be added to the liquidity pool
     * @param liquidityFundAmount - Amount of liquidity fund
     */
    function generateLiquidityTokens(uint256 liquidityFundAmount) external override onlyLauncher returns (uint256 liquidityTokenAmount) {
        liquidityTokenAmount = liquidityFundAmount * FUND_BASED_AMOUNT;
        IFFERC20(token).mint(LAUNCHER, liquidityTokenAmount);
    }

    /**
     * @dev Generate remaining tokens after FFLaunch event
     */
    function generateRemainingTokens(uint256 poolId) external override onlyOwner returns (uint256 remainingTokenAmount) {
        return IFFLauncher(LAUNCHER).generateRemainingTokens(poolId);
    }

    /**
     * @dev Set fund receiver
     * @param _fundReceiver - Address to receive maker fees
     */
    function setFundReceiver(address _fundReceiver) external override onlyOwner {
        fundReceiver = _fundReceiver;
    }
}
