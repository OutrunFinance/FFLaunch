// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./IOutswapV1Router.sol";
import "../core/callee/IPoolCallee.sol";
import "../core/token/interfaces/IFFT.sol";
import "../core/launcher/interfaces/IEthFFLauncher.sol";

/**
 * @dev example - $FF pool callee
 */
contract FFPoolCallee is IPoolCallee, Ownable {
    address public immutable PETH;      // Price token
    address public immutable TOKEN;
    address public immutable LAUNCHER;

    uint256 public constant AMOUNT_PER_MINT_0 = 6000;
    uint256 public constant AMOUNT_PER_MINT_1 = 4500;
    uint256 public constant AMOUNT_PER_MINT_2 = 3000;
    uint256 public constant AMOUNT_BASED_ETH = 4500;

    uint256 public checkPoint0;
    uint256 public checkPoint1;

    modifier onlyLauncher() {
        require(msg.sender == LAUNCHER, "Only launcher");
        _;
    }

    constructor(
        address _owner,
        address _pETH,
        address _token,
        address _launcher,
        uint256 _checkPoint0,
        uint256 _checkPoint1
    ) Ownable(_owner) {
        PETH = _pETH;
        TOKEN = _token;
        LAUNCHER = _launcher;
        checkPoint0 = _checkPoint0;
        checkPoint1 = _checkPoint1;
    }

    function token() public view override returns (address) {
        return TOKEN;
    }

    function launcher() public view override returns (address) {
        return LAUNCHER;
    }

    /**
     * @dev LP need to send to FFLauncher, only FFLauncher can call this function
     * @param outswapRouter Address of OutswapRouter
     * @param deployFundAmount Amount of deployed fund
     */
    function deploy(address outswapRouter, uint256 deployFundAmount) external override onlyLauncher returns (uint256) {
        uint256 deployTokenAmount = deployFundAmount * AMOUNT_BASED_ETH;
        address _token = token();
        IFFT(_token).mint(address(this), deployTokenAmount);
        (,, uint256 liquidity) = IOutswapV1Router(outswapRouter).addLiquidity(
            PETH, _token, deployFundAmount, deployTokenAmount, deployFundAmount, deployTokenAmount, launcher(), block.timestamp + 600
        );

        return liquidity;
    }

    /**
     * @dev Claim the token, only FFLauncher can call this function
     * @param deployFundAmount Amount of deployed fund
     * @param receiver Investor address to receive the token
     */
    function claim(uint256 deployFundAmount, address receiver) external onlyLauncher {
        uint256 currentTime = block.timestamp;
        address _token = token();
        if (currentTime <= checkPoint0) {
            IFFT(_token).mint(receiver, deployFundAmount * AMOUNT_PER_MINT_0);
        } else if (currentTime <= checkPoint1) {
            IFFT(_token).mint(receiver, deployFundAmount * AMOUNT_PER_MINT_1);
        } else {
            IFFT(_token).mint(receiver, deployFundAmount * AMOUNT_PER_MINT_2);
        }
    }

    /**
     * @dev Claim maker fee by FFLauncher
     * @param receiver Address to receive maker fee
     */
    function claimMakerFee(uint256 poolId, address receiver) external onlyOwner {
        IEthFFLauncher(launcher()).claimPoolMakerFee(poolId, receiver);
    }
}
