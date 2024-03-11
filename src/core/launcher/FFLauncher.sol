// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IFFLauncher.sol";
import "../utils/IRETH.sol";
import "../utils/AutoIncrementId.sol";
import "../utils/OutswapV1Library.sol";
import "../utils/IRETHStakeManager.sol";
import "../callee/IPoolCallee.sol";
import "../token/interfaces/IFF.sol";

contract FFLauncher is IFFLauncher, Ownable, AutoIncrementId {
    using SafeERC20 for IERC20;

    uint256 public constant DAY = 24 * 3600;
    address public immutable RETH;
    address public immutable PETH;
    address public immutable REY;
    address public immutable RETHStakeManager;
    address public immutable outswapV1Router;
    address public immutable outswapV1Factory;

    mapping(uint256 poolID => LaunchPool) private _launchPools;
    mapping(uint256 poolID => address callee) private _poolCallees;
    mapping(uint256 poolID => uint256 totalLPs) private _poolTotalLPs;
    mapping(uint256 poolID => mapping(address account => uint256 mintedCount)) private _poolMintedCounts;

    constructor(
        address _owner,
        address _rETH,
        address _pETH,
        address _rey,
        address _outswapV1Router,
        address _outswapV1Factory,
        address _RETHStakeManager
    ) Ownable(_owner) {
        RETH = _rETH;
        PETH = _pETH;
        REY = _rey;
        outswapV1Router = _outswapV1Router;
        outswapV1Factory = _outswapV1Factory;
        RETHStakeManager = _RETHStakeManager;
    }

    function launchPoolOf(uint256 poolId) external view override returns (LaunchPool memory) {
        return _launchPools[poolId];
    }

    function poolCalleeOf(uint256 poolId) external view override returns (address) {
        return _poolCallees[poolId];
    }

    function poolTotalLPsOf(uint256 poolId) external view override returns (uint256) {
        return _poolTotalLPs[poolId];
    }

    function poolMintedCountsOf(uint256 poolId, address account) external view override returns (uint256) {
        return _poolMintedCounts[poolId][account];
    }

    function checkMyPoolLP(uint256 poolId) external view override returns (uint256) {
        return _poolTotalLPs[poolId] * _poolMintedCounts[poolId][msg.sender] / _launchPools[poolId].totalMintedCount;
    }

    /**
     * @dev Mint token from launch pool
     * @param poolId launch pool Id
     */
    function mintFromPool(uint256 poolId) external payable override {
        address msgSender = msg.sender;
        require(msgSender == tx.origin, "Only EOA account");

        uint128 msgVaule = uint128(msg.value);
        LaunchPool storage pool = _launchPools[poolId];
        uint64 lockupDays = pool.lockupDays;
        uint64 deploySignal = pool.deploySignal;
        uint64 mintFee = pool.mintFee;
        uint32 startTime = pool.startTime;
        uint32 endTime = pool.endTime;

        require(msgVaule == mintFee, "Incorrect value");
        uint256 currentTime = block.timestamp;
        require(currentTime <= endTime && currentTime >= startTime, "Invaild pool");

        // 质押锁定获得PETH
        IRETH(RETH).deposit{value: msgVaule}();
        IRETHStakeManager(RETHStakeManager).stake(msgVaule, lockupDays, msgSender, address(this));
        IERC20(REY).safeTransfer(msgSender, mintFee * lockupDays);
        unchecked {
            ++pool.totalMintedCount;
            ++_poolMintedCounts[poolId][msgSender];
        }

        address calleeAddr = _poolCallees[poolId];
        if (pool.totalMintedCount % deploySignal == 0) {
            uint256 deployFeeAmount;
            unchecked {
                deployFeeAmount = deploySignal * mintFee;
            }
            IERC20(PETH).safeTransfer(calleeAddr, deployFeeAmount);

            // 调用项目方注册的callee合约deploy
            uint256 liquidity = IPoolCallee(calleeAddr).deploy(outswapV1Router, deployFeeAmount);
            unchecked {
                _poolTotalLPs[poolId] += liquidity;
            }
        }

        // 调用项目方注册的callee合约mint
        IPoolCallee(calleeAddr).mintTo(msgSender);
    }

    /**
     * @dev Claim your LP by pooId when LP unlocked
     */
    function claimPoolLP(uint256 poolId) external {
        LaunchPool storage pool = _launchPools[poolId];
        address msgSender = msg.sender;
        uint256 mintCount =_poolMintedCounts[poolId][msgSender];
        require(mintCount > 0, "Claim invalid");
        require(block.timestamp >= pool.endTime + pool.lockupDays * DAY, "Locked LP");

        uint256 lpAmount = _poolTotalLPs[poolId] * mintCount / pool.totalMintedCount;
        address pair = OutswapV1Library.pairFor(outswapV1Factory, pool.token, PETH);
        _poolMintedCounts[poolId][msgSender] = 0;
        IERC20(pair).safeTransfer(msgSender, lpAmount);

        emit ClaimPoolLP(poolId, msgSender, lpAmount);
    }

    /**
     * @dev register FF launchPool
     * @param token token address
     * @param mintLimit Limit of total mint
     * @param mintFee Cost per mint
     * @param deploySignal Signal of deploy liquidity
     * @param startTime StartTime of launchpool
     * @param endTime EndTime of launchpool
     * @param lockupDays LockupDay of LP
     */
    function registerPool(
        address token,
        uint256 mintLimit,
        uint64 lockupDays,
        uint64 deploySignal,
        uint64 mintFee,
        uint32 startTime,
        uint32 endTime
    ) external override onlyOwner returns (uint256) {
        uint256 currentTime = block.timestamp;
        require(token != address(0) && startTime < currentTime && endTime > currentTime, "Invalid poolInfo");

        LaunchPool memory pool = LaunchPool(token, mintLimit , lockupDays, deploySignal, mintFee, startTime, endTime, 0);
        uint256 poolId = nextId();
        _launchPools[poolId] = pool;

        emit RegisterPool(poolId, pool);
        return poolId;
    }

    /**
     * @dev register custom launchPool callee by Project team
     * @notice The callee code should be kept as concise as possible and undergo auditing to prevent malicious behavior.
     */
    function registerPoolCallee(uint256 poolId, address calleeAddr) external override onlyOwner {
        LaunchPool memory pool = _launchPools[poolId];
        IPoolCallee poolCallee = IPoolCallee(calleeAddr);
        require(poolCallee.token() == pool.token && poolCallee.launcher() == address(this), "Invalid PoolInfo");
        _poolCallees[poolId] = calleeAddr;

        emit RegisterPoolCallee(poolId, calleeAddr);
    }
}
