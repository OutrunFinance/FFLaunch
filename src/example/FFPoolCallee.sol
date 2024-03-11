// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./IOutswapV1Router.sol";
import "../core/callee/IPoolCallee.sol";
import "../core/token/interfaces/IFF.sol";

/**
 * @dev example - $FF pool callee
 */
contract FFPoolCallee is IPoolCallee, Ownable {
    address public immutable PETH;      // Price token
    address public immutable _token;
    address public immutable _launcher;

    uint256 public constant AMOUNT_PER_MINT_0 = 20;
    uint256 public constant AMOUNT_PER_MINT_1 = 15;
    uint256 public constant AMOUNT_PER_MINT_2 = 10;

    uint256 public constant AMOUNT_PER_DEPLOY = 3000;

    uint256 public checkPoint0;
    uint256 public checkPoint1;

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
    function deploy(address outswapRouter, uint256 deployFeeAmount) external override returns (uint256) {
        require(msg.sender == _launcher, "Only launcher");

        (,, uint256 liquidity) = IOutswapV1Router(outswapRouter).addLiquidity(
            PETH, _token, deployFeeAmount, AMOUNT_PER_DEPLOY, deployFeeAmount, AMOUNT_PER_DEPLOY, _launcher, block.timestamp + 600
        );

        return liquidity;
    }

    function mintTo(address to) external {
        require(msg.sender == _launcher, "Only launcher");

        uint256 currentTime = block.timestamp;
        if (currentTime <= checkPoint0) {
            IFF(_token).mint(to, AMOUNT_PER_MINT_0);
        } else if (currentTime <= checkPoint1) {
            IFF(_token).mint(to, AMOUNT_PER_MINT_1);
        } else {
            IFF(_token).mint(to, AMOUNT_PER_MINT_2);
        }
    }

    function enableTransfer() external onlyOwner {
        IFF(_token).enableTransfer();
    }
}
