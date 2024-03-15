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
    address public immutable _token;
    address public immutable _launcher;

    uint256 public constant AMOUNT_PER_MINT_0 = 6000;
    uint256 public constant AMOUNT_PER_MINT_1 = 4500;
    uint256 public constant AMOUNT_PER_MINT_2 = 3000;
    uint256 public constant AMOUNT_BASED_ETH = 4500;

    uint256 public checkPoint0;
    uint256 public checkPoint1;

    modifier onlyLauncher() {
        require(msg.sender == _launcher, "Only launcher");
        _;
    }

    constructor(
        address _owner,
        address _pETH,
        address token_,
        address launcher_,
        uint256 _checkPoint0,
        uint256 _checkPoint1
    ) Ownable(_owner) {
        PETH = _pETH;
        _token = token_;
        _launcher = launcher_;
        checkPoint0 = _checkPoint0;
        checkPoint1 = _checkPoint1;
    }

    function token() external view override returns (address) {
        return _token;
    }

    function launcher() external view override returns (address) {
        return _launcher;
    }

    /**
     * LP need to send to FFLaunchLpVault
     */
    function deploy(address outswapRouter, uint256 deployFundAmount) external override onlyLauncher returns (uint256) {
        uint256 deployTokenAmount = deployFundAmount * AMOUNT_BASED_ETH;
        IFFT(_token).mint(address(this), deployTokenAmount);
        (,, uint256 liquidity) = IOutswapV1Router(outswapRouter).addLiquidity(
            PETH, _token, deployFundAmount, deployTokenAmount, deployFundAmount, deployTokenAmount, _launcher, block.timestamp + 600
        );

        return liquidity;
    }

    function claim(uint256 fund, address receiver) external onlyLauncher {
        uint256 currentTime = block.timestamp;
        if (currentTime <= checkPoint0) {
            IFFT(_token).mint(receiver, fund * AMOUNT_PER_MINT_0);
        } else if (currentTime <= checkPoint1) {
            IFFT(_token).mint(receiver, fund * AMOUNT_PER_MINT_1);
        } else {
            IFFT(_token).mint(receiver, fund * AMOUNT_PER_MINT_2);
        }
    }
}
