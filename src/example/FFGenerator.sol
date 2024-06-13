// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../core/generator/ITokenGenerator.sol";
import "../core/utils/Initializable.sol";
import "../core/token/interfaces/IFFT.sol";
import "../core/launcher/interfaces/IEthFFLauncher.sol";
import "../blast/GasManagerable.sol";

/**
 * @dev example - $FF generator
 */
contract FFGenerator is ITokenGenerator, Ownable, GasManagerable, Initializable {
    address public immutable LAUNCHER;

    uint256 public constant AMOUNT_PER_MINT_0 = 6000;
    uint256 public constant AMOUNT_PER_MINT_1 = 4500;
    uint256 public constant AMOUNT_PER_MINT_2 = 3000;
    uint256 public constant AMOUNT_BASED_ETH = 4500;

    address private _token;
    uint256 private _checkPoint0;
    uint256 private _checkPoint1;

    modifier onlyLauncher() {
        require(msg.sender == LAUNCHER, "Only launcher");
        _;
    }

    constructor(
        address owner_,
        address launcher_,
        address gasManager_,
        uint256 checkPoint0_,
        uint256 checkPoint1_
    ) Ownable(owner_) GasManagerable(gasManager_) {
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
    function generateLiquidityToken(uint256 deployFundAmount) external override onlyLauncher returns (uint256) {
        uint256 generatedTokenAmount = deployFundAmount * AMOUNT_BASED_ETH;
        IFFT(_token).mint(LAUNCHER, generatedTokenAmount);

        return generatedTokenAmount;
    }

    /**
     * @dev Generate the token when user claim token
     * @param deployFundAmount Amount of deployed fund
     * @param receiver Investor address to receive the token
     * @notice MUST only FFLauncher can call this function
     */
    function generate(uint256 deployFundAmount, address receiver) external override onlyLauncher {
        uint256 currentTime = block.timestamp;
        address tokenAddress = _token;
        if (currentTime <= _checkPoint0) {
            IFFT(tokenAddress).mint(receiver, deployFundAmount * AMOUNT_PER_MINT_0);
        } else if (currentTime <= _checkPoint1) {
            IFFT(tokenAddress).mint(receiver, deployFundAmount * AMOUNT_PER_MINT_1);
        } else {
            IFFT(tokenAddress).mint(receiver, deployFundAmount * AMOUNT_PER_MINT_2);
        }
    }

    /**
     * @dev Generate remaining tokens after FFLaunch event
     * @param vault - Time locked vault address to receive the token
     * @notice MUST can only be called once
     */
    function generateRemainingTokens(address vault) external override onlyOwner {

    }

    /**
     * @dev Claim transaction fees through FFLauncher
     * @param receiver - Address to receive transaction fees
     */
    function claimTransactionFees(uint256 poolId, address receiver) external override onlyOwner {
        IEthFFLauncher(LAUNCHER).claimTransactionFees(poolId, receiver);
    }
}
