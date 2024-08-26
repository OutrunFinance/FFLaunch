// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../core/generator/ITokenGenerator.sol";
import "../core/utils/Initializable.sol";
import "../core/token/interfaces/IFFERC20.sol";
import "../core/launcher/interfaces/IFFLauncher.sol";

/**
 * @dev example - $FF generator
 */
contract FFGenerator is ITokenGenerator, Ownable, Initializable {
    address public immutable LAUNCHER;

    uint256 public constant AMOUNT_PER_MINT_0 = 6000;
    uint256 public constant AMOUNT_PER_MINT_1 = 5000;
    uint256 public constant AMOUNT_PER_MINT_2 = 4000;
    uint256 public constant AMOUNT_BASED_ETH = 5000;

    address private _token;
    uint256 private _checkPoint0;       // Time check point 0
    uint256 private _checkPoint1;       // Time check point 1

    modifier onlyLauncher() {
        require(msg.sender == LAUNCHER, PermissionDenied());
        _;
    }

    constructor(
        address owner_,
        address launcher_,
        uint256 checkPoint0_,
        uint256 checkPoint1_
    ) Ownable(owner_) {
        LAUNCHER = launcher_;
        _checkPoint0 = checkPoint0_;
        _checkPoint1 = checkPoint1_;
    }

    function token() external view override returns (address) {
        return _token;
    }

    function launcher() external view override returns (address) {
        return LAUNCHER;
    }

    function checkPoint0() external view returns (uint256) {
        return _checkPoint0;
    }

    function checkPoint1() external view returns (uint256) {
        return _checkPoint1;
    }

    function initialize(address tokenAddress) external initializer onlyOwner{
        _token = tokenAddress;
    } 

    /**
     * @dev Generate the tokens to be added to the liquidity pool
     * @param deployFundAmount - Amount of deployed fund
     */
    function generateLiquidityToken(uint256 deployFundAmount) external override onlyLauncher returns (uint256 liquidityTokenAmount) {
        liquidityTokenAmount = deployFundAmount * AMOUNT_BASED_ETH;
        IFFERC20(_token).mint(LAUNCHER, liquidityTokenAmount);
    }

    /**
     * @dev Generate the token when user claim token
     * @param deployFundAmount Amount of deployed fund
     * @param receiver Investor address to receive the token
     * @notice MUST only FFLauncher can call this function
     */
    function generateInvestorToken(uint256 deployFundAmount, address receiver) external override onlyLauncher returns (uint256 investorTokenAmount) {
        uint256 currentTime = block.timestamp;
        address tokenAddress = _token;
        if (currentTime <= _checkPoint0) {
            investorTokenAmount = deployFundAmount * AMOUNT_PER_MINT_0;
        } else if (currentTime <= _checkPoint1) {
            investorTokenAmount = deployFundAmount * AMOUNT_PER_MINT_1;
        } else {
            investorTokenAmount = deployFundAmount * AMOUNT_PER_MINT_2;
        }

        IFFERC20(tokenAddress).mint(receiver, investorTokenAmount);
    }

    /**
     * @dev Generate remaining tokens after FFLaunch event
     */
    function generateRemainingTokens(uint256 poolId) external override onlyOwner returns (uint256 remainingTokenAmount) {
        return IFFLauncher(LAUNCHER).generateRemainingTokens(poolId);
    }

    /**
     * @dev Claim transaction fees through FFLauncher
     * @param receiver - Address to receive transaction fees
     */
    function claimTransactionFees(uint256 poolId, address receiver) external override onlyOwner {
        IFFLauncher(LAUNCHER).claimTransactionFees(poolId, receiver);
    }
}
