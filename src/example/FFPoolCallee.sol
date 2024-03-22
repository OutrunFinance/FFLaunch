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
     * LP need to send to FFLaunchLpVault
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

    function claim(uint256 fund, address receiver) external onlyLauncher {
        uint256 currentTime = block.timestamp;
        address _token = token();
        if (currentTime <= checkPoint0) {
            IFFT(_token).mint(receiver, fund * AMOUNT_PER_MINT_0);
        } else if (currentTime <= checkPoint1) {
            IFFT(_token).mint(receiver, fund * AMOUNT_PER_MINT_1);
        } else {
            IFFT(_token).mint(receiver, fund * AMOUNT_PER_MINT_2);
        }
    }

    function claimMakerFee(uint256 poolId, address to) external onlyOwner {
        IEthFFLauncher(launcher()).claimPoolMakerFee(poolId, to);
    }
}
