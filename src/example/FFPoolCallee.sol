// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../core/callee/IPoolCallee.sol";
import "../core/utils/Initializable.sol";
import "../core/token/interfaces/IFFT.sol";
import "../core/launcher/interfaces/IEthFFLauncher.sol";
import "../blast/GasManagerable.sol";

/**
 * @dev example - $FF pool callee
 */
contract FFPoolCallee is IPoolCallee, Ownable, GasManagerable, Initializable {
    address public immutable PETH;      // Price token
    address public immutable LAUNCHER;

    uint256 public constant AMOUNT_PER_MINT_0 = 6000;
    uint256 public constant AMOUNT_PER_MINT_1 = 4500;
    uint256 public constant AMOUNT_PER_MINT_2 = 3000;
    uint256 public constant AMOUNT_BASED_ETH = 4500;

    address private _token;
    uint256 public checkPoint0;
    uint256 public checkPoint1;

    modifier onlyLauncher() {
        require(msg.sender == LAUNCHER, "Only launcher");
        _;
    }

    constructor(
        address _owner,
        address _pETH,
        address _launcher,
        address _gasManager,
        uint256 _checkPoint0,
        uint256 _checkPoint1
    ) Ownable(_owner) GasManagerable(_gasManager) {
        PETH = _pETH;
        LAUNCHER = _launcher;
        checkPoint0 = _checkPoint0;
        checkPoint1 = _checkPoint1;
    }

    function token() public view override returns (address) {
        return _token;
    }

    function launcher() public view override returns (address) {
        return LAUNCHER;
    }

    function initialize(address token_) external initializer onlyOwner{
        _token = token_;
    } 

    /**
     * @dev Get deployed token, send to FFLauncher, Only FFLauncher can call this function
     * @param deployFundAmount Amount of deployed fund
     */
    function getDeployedToken(uint256 deployFundAmount) external override onlyLauncher returns (uint256) {
        uint256 deployTokenAmount = deployFundAmount * AMOUNT_BASED_ETH;
        IFFT(token()).mint(launcher(), deployTokenAmount);

        return deployTokenAmount;
    }

    /**
     * @dev Claim the token, only FFLauncher can call this function
     * @param deployFundAmount Amount of deployed fund
     * @param receiver Investor address to receive the token
     */
    function claim(uint256 deployFundAmount, address receiver) external onlyLauncher {
        uint256 currentTime = block.timestamp;
        address token_ = token();
        if (currentTime <= checkPoint0) {
            IFFT(token_).mint(receiver, deployFundAmount * AMOUNT_PER_MINT_0);
        } else if (currentTime <= checkPoint1) {
            IFFT(token_).mint(receiver, deployFundAmount * AMOUNT_PER_MINT_1);
        } else {
            IFFT(token_).mint(receiver, deployFundAmount * AMOUNT_PER_MINT_2);
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
