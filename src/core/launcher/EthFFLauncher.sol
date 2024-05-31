// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IEthFFLauncher.sol";
import "../utils/IORETH.sol";
import "../utils/AutoIncrementId.sol";
import "../utils/OutswapV1Library.sol";
import "../utils/IOutswapV1Router.sol";
import "../utils/IOutswapV1Pair.sol";
import "../utils/IORETHStakeManager.sol";
import "../callee/IPoolCallee.sol";
import "../token/interfaces/IFFT.sol";
import "../../blast/GasManagerable.sol";

contract EthFFLauncher is IEthFFLauncher, Ownable, GasManagerable, AutoIncrementId {
    using SafeERC20 for IERC20;

    uint256 public constant DAY = 24 * 3600;
    address public immutable ORETH;
    address public immutable OSETH;
    address public immutable orETHStakeManager;
    address public immutable outswapV1Router;
    address public immutable outswapV1Factory;

    mapping(uint256 poolId => LaunchPool) private _launchPools;
    mapping(uint256 poolId => uint256) private _tempFund;
    mapping(bytes32 beacon => uint256) private _tempFundPool;
    mapping(bytes32 beacon => uint256) private _poolFunds;
    mapping(bytes32 beacon => bool) private _isPoolLiquidityClaimed;

    constructor(
        address _owner,
        address _orETH,
        address _osETH,
        address _gasManager,
        address _outswapV1Router,
        address _outswapV1Factory,
        address _orETHStakeManager
    ) Ownable(_owner) GasManagerable(_gasManager) {
        ORETH = _orETH;
        OSETH = _osETH;
        outswapV1Router = _outswapV1Router;
        outswapV1Factory = _outswapV1Factory;
        orETHStakeManager = _orETHStakeManager;

        IERC20(ORETH).approve(_orETHStakeManager, type(uint256).max);
        IERC20(OSETH).approve(_outswapV1Router, type(uint256).max);
    }

    function launchPool(uint256 poolId) external view override returns (LaunchPool memory) {
        return _launchPools[poolId];
    }

    function tempFund(uint256 poolId) external view override returns (uint256) {
        return _tempFund[poolId];
    }

    function tempFundPool(uint256 poolId, address account) external view override returns (uint256) {
        return _tempFundPool[getBeacon(poolId, account)];
    }

    function poolFunds(uint256 poolId, address account) external view override returns (uint256) {
        return _poolFunds[getBeacon(poolId, account)];
    }

    function isPoolLiquidityClaimed(uint256 poolId, address account) external view override returns (bool) {
        return _isPoolLiquidityClaimed[getBeacon(poolId, account)];
    }

    function viewPoolLiquidity(uint256 poolId) external view override returns (uint256) {
        LaunchPool storage pool = _launchPools[poolId];
        return pool.totalLiquidity * _poolFunds[getBeacon(poolId, msg.sender)] / pool.totalActualFund;
    }

    function getBeacon(uint256 poolId, address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(poolId, account));
    }

    /**
     * @dev Deposit temporary fund
     */
    function depositToTempFundPool() public payable override {
        address msgSender = msg.sender;
        require(msgSender == tx.origin, "Only EOA account");

        uint256 msgValue = msg.value;
        uint256 poolId = id;
        LaunchPool storage pool = _launchPools[poolId];
        uint64 startTime = pool.startTime;
        uint64 endTime = pool.endTime;
        uint128 maxDeposit = pool.maxDeposit;
        uint256 currentTime = block.timestamp;
        require(currentTime > startTime && currentTime < endTime, "Invalid time");
        require(msgValue <= maxDeposit, "Invalid vaule");

        unchecked {
            _tempFund[poolId] += msgValue;
            _tempFundPool[getBeacon(poolId, msgSender)] += msgValue;
        }
    }

    /**
     * @dev Claim token or refund after claimDeadline
     */
    function claimTokenOrFund(uint256 poolId) external override {
        address msgSender = msg.sender;
        LaunchPool storage pool = _launchPools[poolId];
        bytes32 beacon = getBeacon(poolId, msgSender);
        uint256 fund = _tempFundPool[beacon];
        require(fund > 0, "No fund");

        _tempFund[poolId] -= fund;
        _tempFundPool[beacon] = 0;

        uint128 lockupDays = pool.lockupDays;
        uint128 claimDeadline = pool.claimDeadline;
        uint256 currentTime = block.timestamp;
        if (currentTime < claimDeadline) {
            IORETH(ORETH).deposit{value: fund}();
            (uint256 amountInOSETH, ) = IORETHStakeManager(orETHStakeManager).stake(fund, lockupDays, msgSender, address(this), msgSender);

            // Calling the registered Callee contract to get deployed token and mint token to user
            address callee = pool.callee;
            uint256 deployTokenAmount = IPoolCallee(callee).getDeployedToken(amountInOSETH);

            address token = pool.token;
            IERC20(token).approve(outswapV1Router, deployTokenAmount);
            (,, uint256 liquidity) = IOutswapV1Router(outswapV1Router).addLiquidity(
                OSETH, token, amountInOSETH, deployTokenAmount, amountInOSETH, deployTokenAmount, address(this), block.timestamp + 600
            );
            IPoolCallee(callee).claim(amountInOSETH, msgSender);
            unchecked {
                pool.totalLiquidity += uint128(liquidity);
                pool.totalActualFund += uint128(amountInOSETH);
                _poolFunds[beacon] += amountInOSETH;
            }
        } else {
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
        require(!IFFT(token).transferable(), "Already enable transfer");
        IFFT(token).enableTransfer();
    }

    /**
     * @dev Claim your liquidity by pooId when liquidity unlocked
     */
    function claimPoolLiquidity(uint256 poolId) external override {
        address msgSender = msg.sender;
        LaunchPool storage pool = _launchPools[poolId];
        bytes32 beacon = getBeacon(poolId, msgSender);
        uint256 fund = _poolFunds[beacon];
        require(fund > 0, "No fund");
        require(!_isPoolLiquidityClaimed[beacon], "Already claimed");
        require(block.timestamp >= pool.claimDeadline + pool.lockupDays * DAY, "Locked liquidity");

        uint256 lpAmount = pool.totalLiquidity * fund / pool.totalActualFund;
        address pair = OutswapV1Library.pairFor(outswapV1Factory, pool.token, OSETH);
        _isPoolLiquidityClaimed[beacon] = true;
        IERC20(pair).safeTransfer(msgSender, lpAmount);

        emit ClaimPoolLiquidity(poolId, msgSender, lpAmount);
    }

    /**
     * @dev Claim pool maker fee
     * @param receiver Address to receive maker fee
     */
    function claimPoolMakerFee(uint256 poolId, address receiver) external override {
        address msgSender = msg.sender;
        LaunchPool storage pool = _launchPools[poolId];
        require(msgSender == pool.callee && block.timestamp > pool.claimDeadline, "Permission denied");

        address pair = OutswapV1Library.pairFor(outswapV1Factory, pool.token, OSETH);
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
     * @param maxDeposit Max fee per deposit
     * @param claimDeadline Deadline of claim token
     * @param lockupDays LockupDay of liquidity
     * @notice The callee code should be kept as concise as possible and undergo auditing to prevent malicious behavior.
     */
    function registerPool(
        address token,
        address callee,
        uint64 startTime,
        uint64 endTime,
        uint128 maxDeposit,
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

        LaunchPool memory pool = LaunchPool(token, callee, claimDeadline, lockupDays, 0, 0, maxDeposit, startTime, endTime);
        poolId = nextId();
        _launchPools[poolId] = pool;

        emit RegisterPool(poolId, pool);
    }

    receive() external payable {
        depositToTempFundPool();
    }
}
