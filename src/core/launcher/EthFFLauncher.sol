// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IEthFFLauncher.sol";
import "../utils/IRETH.sol";
import "../utils/AutoIncrementId.sol";
import "../utils/OutswapV1Library.sol";
import "../utils/IRETHStakeManager.sol";
import "../callee/IPoolCallee.sol";
import "../token/interfaces/IFF.sol";

contract EthFFLauncher is IEthFFLauncher, Ownable, AutoIncrementId {
    using SafeERC20 for IERC20;

    uint256 public constant DAY = 24 * 3600;
    address public immutable PETH;
    address public immutable RETHStakeManager;
    address public immutable outswapV1Router;
    address public immutable outswapV1Factory;

    mapping(uint256 poolID => LaunchPool) private _launchPools;
    mapping(uint256 poolID => mapping(address account => uint256)) private _poolMintedCounts;
    mapping(uint256 poolID => mapping(address account => bool)) private _isPoolLPClaimed;

    constructor(
        address _owner,
        address _pETH,
        address _outswapV1Router,
        address _outswapV1Factory,
        address _RETHStakeManager
    ) Ownable(_owner) {
        PETH = _pETH;
        outswapV1Router = _outswapV1Router;
        outswapV1Factory = _outswapV1Factory;
        RETHStakeManager = _RETHStakeManager;
    }

    function launchPoolOf(uint256 poolId) external view override returns (LaunchPool memory) {
        return _launchPools[poolId];
    }

    function poolMintedCountsOf(uint256 poolId, address account) external view override returns (uint256) {
        return _poolMintedCounts[poolId][account];
    }

    function isPoolLPClaimedOf(uint256 poolId, address account) external view override returns (bool) {
        return _isPoolLPClaimed[poolId][account];
    }

    function checkMyPoolLP(uint256 poolId) external view override returns (uint256) {
        LaunchPool storage pool = _launchPools[poolId];
        return pool.totalLP * _poolMintedCounts[poolId][msg.sender] / pool.totalMintedCount;
    }

    /**
     * @dev Mint token from launch pool
     * @param poolId launch pool Id
     */
    function mintFromPool(uint256 poolId) external payable override {
        address msgSender = msg.sender;
        require(msgSender == tx.origin, "Only EOA account");

        LaunchPool storage pool = _launchPools[poolId];
        bool closed = pool.isClosed;
        uint48 startTime = pool.startTime;
        uint48 endTime = pool.endTime;
        uint128 mintFee = pool.mintFee;
        uint256 currentTime = block.timestamp;
        require(!closed, "Already closed");
        require(currentTime >= startTime, "Not started");

        IERC20(PETH).safeTransferFrom(msgSender, address(this), mintFee);
        unchecked {
            ++pool.totalMintedCount;
            ++_poolMintedCounts[poolId][msgSender];
        }

        address callee = pool.callee;
        if (pool.totalMintedCount % pool.deploySignal == 0) {
            uint256 liquidity = _deployLiquidity(callee);
            unchecked {
                pool.totalLP += liquidity;
            }
        }

        if (currentTime >= endTime) {
            uint256 liquidity = _deployLiquidity(callee);
            unchecked {
                pool.totalLP += liquidity;
            }
            pool.isClosed = true;

            IFF(pool.token).enableTransfer();
        }

        // Calling the registered Callee contract to mint
        IPoolCallee(callee).mintTo(msgSender);
    }

    /**
     * @dev Claim your LP by pooId when LP unlocked
     */
    function claimPoolLP(uint256 poolId) external {
        LaunchPool storage pool = _launchPools[poolId];
        address msgSender = msg.sender;
        uint256 mintCount =_poolMintedCounts[poolId][msgSender];
        require(!_isPoolLPClaimed[poolId][msgSender], "Already claimed");
        require(block.timestamp >= pool.endTime + pool.lockupDays * DAY, "Locked LP");

        uint256 lpAmount = pool.totalLP * mintCount / pool.totalMintedCount;
        address pair = OutswapV1Library.pairFor(outswapV1Factory, pool.token, PETH);
        _isPoolLPClaimed[poolId][msgSender] = true;
        IERC20(pair).safeTransfer(msgSender, lpAmount);

        emit ClaimPoolLP(poolId, msgSender, lpAmount);
    }

    /**
     * @dev register FF launchPool
     * @param token Token address
     * @param callee Callee address
     * @param lockupDays LockupDay of LP
     * @param deploySignal The signal of deploy
     * @param startTime StartTime of launchpool
     * @param endTime EndTime of launchpool
     * @param mintFee Cost per mint
     * @notice The callee code should be kept as concise as possible and undergo auditing to prevent malicious behavior.
     */
    function registerPool(
        address token,
        address callee,
        uint16 lockupDays,
        uint16 deploySignal,
        uint48 startTime,
        uint48 endTime,
        uint128 mintFee
    ) external override onlyOwner returns (uint256) {
        uint256 currentTime = block.timestamp;
        require(token != address(0) && startTime < currentTime && endTime > currentTime, "Invalid poolInfo");
        IPoolCallee poolCallee = IPoolCallee(callee);
        require(poolCallee.token() == token && poolCallee.launcher() == address(this), "Invalid callee");

        LaunchPool memory pool = LaunchPool(token, callee, lockupDays, deploySignal, startTime, endTime, mintFee, 0, 0, 0, false);
        uint256 poolId = nextId();
        _launchPools[poolId] = pool;

        emit RegisterPool(poolId, pool);
        return poolId;
    }

    function _deployLiquidity(address callee) internal returns (uint256) {
        uint256 deployFeeAmount = IERC20(PETH).balanceOf(address(this));
        IERC20(PETH).safeTransfer(callee, deployFeeAmount);
        return IPoolCallee(callee).deploy(outswapV1Router, deployFeeAmount);
    }
}
