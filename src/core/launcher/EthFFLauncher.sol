// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


import "./interfaces/IEthFFLauncher.sol";
import "../utils/IRETH.sol";
import "../utils/AutoIncrementId.sol";
import "../utils/OutswapV1Library.sol";
import "../utils/IOutswapV1Router.sol";
import "../utils/IOutswapV1Pair.sol";
import "../utils/IRETHStakeManager.sol";
import "../callee/IPoolCallee.sol";
import "../token/interfaces/IFFT.sol";
import "../../blast/GasManagerable.sol";

contract EthFFLauncher is IEthFFLauncher, Ownable, GasManagerable, AutoIncrementId {
    using SafeERC20 for IERC20;

    uint256 public constant DAY = 24 * 3600;
    address public immutable RETH;
    address public immutable PETH;
    address public immutable RETHStakeManager;
    address public immutable outswapV1Router;
    address public immutable outswapV1Factory;

    mapping(uint256 poolID => uint256) private _tempFund;
    mapping(uint256 poolID => LaunchPool) private _launchPools;
    mapping(uint256 poolID => mapping(address account => uint256)) private _poolFunds;
    mapping(uint256 poolID => mapping(address account => uint256)) private _tempFundPool;
    mapping(uint256 poolID => mapping(address account => bool)) private _isPoolLPClaimed;

    constructor(
        address _owner,
        address _rETH,
        address _pETH,
        address _gasManager,
        address _outswapV1Router,
        address _outswapV1Factory,
        address _RETHStakeManager
    ) Ownable(_owner) GasManagerable(_gasManager) {
        RETH = _rETH;
        PETH = _pETH;
        outswapV1Router = _outswapV1Router;
        outswapV1Factory = _outswapV1Factory;
        RETHStakeManager = _RETHStakeManager;
    }

    function tempFund(uint256 poolId) external view override returns (uint256) {
        return _tempFund[poolId];
    }

    function launchPool(uint256 poolId) external view override returns (LaunchPool memory) {
        return _launchPools[poolId];
    }

    function tempFundPool(uint256 poolId, address account) external view override returns (uint256) {
        return _tempFundPool[poolId][account];
    }

    function isPoolLPClaimed(uint256 poolId, address account) external view override returns (bool) {
        return _isPoolLPClaimed[poolId][account];
    }

    function viewMyPoolLP(uint256 poolId) external view override returns (uint256) {
        LaunchPool storage pool = _launchPools[poolId];
        return pool.totalLP * _poolFunds[poolId][msg.sender] / pool.totalActualFund;
    }

    /**
     * @dev Deposit temporary fund
     */
    function deposit() public payable override {
        address msgSender = msg.sender;
        require(msgSender == tx.origin, "Only EOA account");

        uint256 msgValue = msg.value;
        uint256 poolId = id;
        LaunchPool storage pool = _launchPools[poolId];
        uint64 startTime = pool.startTime;
        uint64 endTime = pool.endTime;
        uint128 maxFee = pool.maxFee;
        uint256 currentTime = block.timestamp;
        require(msgValue <= maxFee, "Invalid vaule");
        require(currentTime > startTime && currentTime < endTime, "Invalid time");

        unchecked {
            _tempFund[poolId] += msgValue;
            _tempFundPool[poolId][msgSender] += msgValue;
        }
    }

    /**
     * @dev Claim token or refund after claimDeadline
     */
    function claimTokenOrFund(uint256 poolId) external override {
        address msgSender = msg.sender;
        LaunchPool storage pool = _launchPools[poolId];
        uint128 claimDeadline = pool.claimDeadline;
        uint128 lockupDays = pool.lockupDays;
        uint256 currentTime = block.timestamp;
        uint256 fund = _tempFundPool[poolId][msgSender];
        require(fund > 0, "No fund");

        if (currentTime < claimDeadline) {
            _tempFund[poolId] -= fund;
            _tempFundPool[poolId][msgSender] = 0;
            
            IRETH(RETH).deposit{value: fund}();
            IERC20(RETH).approve(RETHStakeManager, fund);
            (uint256 amountInPETH, ) = IRETHStakeManager(RETHStakeManager).stake(fund, lockupDays, msgSender, address(this), msgSender);

            // Calling the registered Callee contract to get deployed token and mint token to user
            address callee = pool.callee;
            uint256 deployTokenAmount = IPoolCallee(callee).getDeployedToken(amountInPETH);

            address token = pool.token;
            IERC20(PETH).approve(outswapV1Router, amountInPETH);
            IERC20(token).approve(outswapV1Router, deployTokenAmount);
            (,, uint256 liquidity) = IOutswapV1Router(outswapV1Router).addLiquidity(
                PETH, token, amountInPETH, deployTokenAmount, amountInPETH, deployTokenAmount, address(this), block.timestamp + 600
            );
            IPoolCallee(callee).claim(amountInPETH, msgSender);
            unchecked {
                pool.totalLP += uint128(liquidity);
                pool.totalActualFund += uint128(amountInPETH);
                _poolFunds[poolId][msgSender] += amountInPETH;
            }
        } else {
            _tempFund[poolId] -= fund;
            _tempFundPool[poolId][msgSender] = 0;
            Address.sendValue(payable(msgSender), fund);
        }
    }

    /**
     * @dev Enable transfer about token of pool
     */
    function enablePoolTokenTransfer(uint256 poolId) external override {
        LaunchPool storage pool = _launchPools[poolId];
        address token = pool.token;
        require(block.timestamp >= pool.claimDeadline, "Pool not closed");
        require(!IFFT(token).enableTransfer(), "Already enable transfer");
        IFFT(token).enableTransfer();
    }

    /**
     * @dev Claim your LP by pooId when LP unlocked
     */
    function claimPoolLP(uint256 poolId) external override {
        LaunchPool storage pool = _launchPools[poolId];
        address msgSender = msg.sender;
        uint256 fund = _poolFunds[poolId][msgSender];
        require(!_isPoolLPClaimed[poolId][msgSender], "Already claimed");
        require(block.timestamp >= pool.claimDeadline + pool.lockupDays * DAY, "Locked LP");

        uint256 lpAmount = pool.totalLP * fund / pool.totalActualFund;
        address pair = OutswapV1Library.pairFor(outswapV1Factory, pool.token, PETH);
        _isPoolLPClaimed[poolId][msgSender] = true;
        IERC20(pair).safeTransfer(msgSender, lpAmount);

        emit ClaimPoolLP(poolId, msgSender, lpAmount);
    }

    /**
     * @dev Claim your LP by pooId when LP unlocked
     * @param receiver Address to receive maker fee
     */
    function claimPoolMakerFee(uint256 poolId, address receiver) external override {
        address msgSender = msg.sender;
        LaunchPool storage pool = _launchPools[poolId];
        require(msgSender == pool.callee && block.timestamp > pool.claimDeadline, "Permission denied");

        address pair = OutswapV1Library.pairFor(outswapV1Factory, pool.token, PETH);
        uint256 makerFee = IOutswapV1Pair(pair).claimMakerFee();
        IERC20(pair).safeTransfer(receiver, makerFee);

        emit ClaimPoolMakerFee(poolId, receiver, makerFee);
    }

    /**
     * @dev register FF launchPool
     * @param token Token address
     * @param callee Callee address
     * @param startTime StartTime of launchpool
     * @param endTime EndTime of launchpool
     * @param maxFee Max fee per deposit
     * @param claimDeadline Deadline of claim token
     * @param lockupDays LockupDay of LP
     * @notice The callee code should be kept as concise as possible and undergo auditing to prevent malicious behavior.
     */
    function registerPool(
        address token,
        address callee,
        uint64 startTime,
        uint64 endTime,
        uint128 maxFee,
        uint128 claimDeadline,
        uint128 lockupDays
    ) external override onlyOwner returns (uint256 poolId) {
        uint256 currentTime = block.timestamp;
        require(token != address(0) && startTime < currentTime && endTime > currentTime, "Invalid poolInfo");
        IPoolCallee poolCallee = IPoolCallee(callee);
        require(poolCallee.token() == token && poolCallee.launcher() == address(this), "Invalid callee");
        uint256 currentPoolId = id;
        LaunchPool storage currentPool = _launchPools[currentPoolId];
        require(currentTime > currentPool.claimDeadline, "Last pool ongoing");

        LaunchPool memory pool = LaunchPool(token, callee, startTime, endTime, maxFee, claimDeadline, lockupDays, 0, 0);
        poolId = nextId();
        _launchPools[poolId] = pool;

        emit RegisterPool(poolId, pool);
    }

    receive() external payable {
        deposit();
    }
}
