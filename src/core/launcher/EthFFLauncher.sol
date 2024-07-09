// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IFFLauncher.sol";
import "../utils/IORETH.sol";
import "../utils/AutoIncrementId.sol";
import "../utils/OutswapV1Library.sol";
import "../utils/IOutswapV1Router.sol";
import "../utils/IOutswapV1Pair.sol";
import "../utils/IORETHStakeManager.sol";
import "../generator/ITokenGenerator.sol";
import "../token/FFLiquidProof.sol";
import "../token/interfaces/IFFT.sol";
import "../token/interfaces/IFFLiquidProof.sol";
import "../../blast/GasManagerable.sol";

/**
 * @title EthFFLauncher
 */
contract EthFFLauncher is IFFLauncher, Ownable, GasManagerable, AutoIncrementId {
    using SafeERC20 for IERC20;

    uint256 public constant DAY = 24 * 3600;
    uint256 public constant RATIO = 10000;
    address public immutable ORETH;
    address public immutable OSETH;
    address public immutable orETHStakeManager;
    address public immutable outswapV1Router;
    address public immutable outswapV1Factory;

    mapping(uint256 poolId => LaunchPool) private _launchPools;
    mapping(uint256 poolId => uint256) private _tempFund;
    mapping(bytes32 beacon => uint256) private _tempFundPool;

    constructor(
        address _owner,
        address _orETH,
        address _osETH,
        address _gasManager,
        address _outswapV1Factory,
        address _outswapV1Router,
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

    function launchPools(uint256 poolId) external view override returns (LaunchPool memory) {
        return _launchPools[poolId];
    }

    function tempFund(uint256 poolId) external view override returns (uint256) {
        return _tempFund[poolId];
    }

    function tempFundPool(uint256 poolId, address account) external view override returns (uint256) {
        return _tempFundPool[getBeacon(poolId, account)];
    }

    function getBeacon(uint256 poolId, address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(poolId, account));
    }

    /**
     * @dev Deposit temporary fund
     */
    function depositToTempFundPool() public payable {
        address msgSender = msg.sender;
        require(msgSender == tx.origin, "Only EOA account");

        uint256 msgValue = msg.value;
        uint256 poolId = id;
        LaunchPool storage pool = _launchPools[poolId];
        uint256 currentTime = block.timestamp;
        uint128 maxDeposit = pool.maxDeposit;
        uint64 startTime = pool.startTime;
        uint64 endTime = pool.endTime;
        require(currentTime > startTime && currentTime < endTime, "Invalid time");
        require(msgValue <= maxDeposit, "Invalid vaule");

        unchecked {
            _tempFund[poolId] += msgValue;
            _tempFundPool[getBeacon(poolId, msgSender)] += msgValue;
        }
    }

    /**
     * @dev Claim token or refund after endTime
     * @param poolId - LaunchPool id
     */
    function claimTokenOrFund(uint256 poolId) external override {
        address msgSender = msg.sender;
        LaunchPool storage pool = _launchPools[poolId];
        bytes32 beacon = getBeacon(poolId, msgSender);
        uint256 fund = _tempFundPool[beacon];
        require(fund > 0, "No fund");

        _tempFund[poolId] -= fund;
        _tempFundPool[beacon] = 0;

        uint64 endTime = pool.endTime;
        uint256 lockupDays = pool.lockupDays;
        uint256 currentTime = block.timestamp;
        if (currentTime < endTime) {
            IORETH(ORETH).deposit{value: fund}();
            (uint256 amountInOSETH,) = IORETHStakeManager(orETHStakeManager).stake(fund, lockupDays, msgSender, address(this), msgSender);

            // Calling the registered tokenGenerator contract to get liquidity token and mint token to user
            address generator = pool.generator;
            uint256 investorTokenAmount = ITokenGenerator(generator).generateInvestorToken(amountInOSETH, msgSender);
            uint256 liquidityTokenAmount = ITokenGenerator(generator).generateLiquidityToken(amountInOSETH);
            address token = pool.token;
            address router = outswapV1Router;
            IERC20(token).approve(router, liquidityTokenAmount);
            (,, uint256 liquidity) = IOutswapV1Router(router).addLiquidity(
                OSETH,
                token,
                amountInOSETH,
                liquidityTokenAmount,
                amountInOSETH,
                liquidityTokenAmount,
                address(this),
                block.timestamp + 600
            );
            IFFLiquidProof(pool.liquidProof).mint(msgSender, liquidity);
            unchecked {
                pool.totalLiquidityFund += amountInOSETH;

                uint256 mintedAmount = pool.mintedAmount + liquidityTokenAmount + investorTokenAmount;
                uint256 totalSupply = pool.totalSupply;

                // if totalSupply == 0, indicates an unlimited amount of mintable tokens
                if (totalSupply != 0) {
                    uint256 mintableAmount = totalSupply * pool.sharePercent / RATIO;
                    require(mintedAmount <= mintableAmount, "Insufficient amount of mintable tokens");
                }
                pool.mintedAmount = mintedAmount;
            }
        } else {
            Address.sendValue(payable(msgSender), fund);
        }
    }

    /**
     * @dev Enable transfer about token of pool
     * @param poolId - LaunchPool id
     */
    function enablePoolTokenTransfer(uint256 poolId) external override {
        LaunchPool storage pool = _launchPools[poolId];
        address token = pool.token;
        require(block.timestamp >= pool.endTime, "Pool not closed");
        require(!IFFT(token).transferable(), "Already enable transfer");
        IFFT(token).enableTransfer();
    }

    /**
     * @dev Claim your liquidity by pooId when liquidity unlocked
     * @param poolId - LaunchPool id
     * @param claimedLiquidity - Claimed liquidity
     */
    function claimPoolLiquidity(uint256 poolId, uint256 claimedLiquidity) external override {
        address msgSender = msg.sender;
        LaunchPool storage pool = _launchPools[poolId];
        require(block.timestamp >= pool.endTime + pool.lockupDays * DAY, "Locked liquidity");
        IFFLiquidProof(pool.liquidProof).burn(msgSender, claimedLiquidity);

        address pair = OutswapV1Library.pairFor(outswapV1Factory, pool.token, OSETH);
        IERC20(pair).safeTransfer(msgSender, claimedLiquidity);

        emit ClaimPoolLiquidity(poolId, msgSender, claimedLiquidity);
    }

    /**
     * @dev Claim transaction fees of liquidity pool
     * @param poolId - LaunchPool id
     * @param receiver - Address to receive transaction fees
     */
    function claimTransactionFees(uint256 poolId, address receiver) external override {
        address msgSender = msg.sender;
        LaunchPool storage pool = _launchPools[poolId];
        require(msgSender == pool.generator, "Permission denied");
        require(block.timestamp > pool.endTime, "After end time");

        address pairAddress = OutswapV1Library.pairFor(outswapV1Factory, pool.token, OSETH);
        IOutswapV1Pair pair = IOutswapV1Pair(pairAddress);
        (uint256 amount0, uint256 amount1) = pair.claimMakerFee();
        IERC20(pair.token0()).safeTransfer(receiver, amount0);
        IERC20(pair.token1()).safeTransfer(receiver, amount1);

        emit ClaimTransactionFees(poolId, receiver, amount0, amount1);
    }

    /**
     * @dev Generate remaining tokens after FFLaunch event
     * @param poolId - LaunchPool id
     * @notice Only generator can call, only can call once
     */
    function generateRemainingTokens(uint256 poolId) external returns (uint256 remainingTokenAmount) {
        LaunchPool storage pool = _launchPools[poolId];
        uint256 sharePercent = pool.sharePercent;
        require(sharePercent < RATIO, "No more token");
        require(!pool.areAllGenerated, "Already generated");
        address msgSender = msg.sender;
        require(msgSender == pool.generator, "Permission denied");
        require(block.timestamp >= pool.endTime + (pool.lockupDays + 7) * DAY, "Time not reached");

        pool.areAllGenerated = true;
        uint256 totalSupply = pool.totalSupply;
        uint256 mintedAmount = pool.mintedAmount;
        if (totalSupply == 0) {
            remainingTokenAmount = (RATIO - sharePercent) * mintedAmount / sharePercent;
        } else {
            remainingTokenAmount = totalSupply - mintedAmount;
        }
        
        address token = pool.token;
        address timeLockVault = pool.timeLockVault;
        IFFT(token).mint(timeLockVault, remainingTokenAmount);

        emit GenerateRemainingTokens(poolId, token, timeLockVault, remainingTokenAmount);
    }

    /**
     * @dev Register FF launchPool
     * @param poolParam - Pool param
     * @notice The tokenGenerator code should be kept as concise as possible and undergo auditing to prevent malicious behavior.
     */
    function registerPool(LaunchPool calldata poolParam) external override onlyOwner returns (uint256 poolId) {
        uint256 currentTime = block.timestamp;
        address token = poolParam.token;
        address timeLockVault = poolParam.timeLockVault;
        uint64 startTime = poolParam.startTime;
        uint64 endTime = poolParam.endTime;
        uint128 maxDeposit = poolParam.maxDeposit;
        uint256 sharePercent = poolParam.sharePercent;
        require(
            token != address(0) && 
            timeLockVault != address(0) &&
            startTime > currentTime && 
            endTime > currentTime && 
            maxDeposit > 0 && 
            sharePercent > 0 && 
            sharePercent <= RATIO, 
            "Invalid poolInfo"
        );

        address generator = poolParam.generator;
        ITokenGenerator tokenGenerator = ITokenGenerator(generator);
        require(tokenGenerator.token() == token && tokenGenerator.launcher() == address(this), "Invalid token generator");

        uint256 currentPoolId = id;
        if (currentPoolId != 0) {
            require(currentTime > _launchPools[currentPoolId].endTime, "Last pool ongoing");
        }

        FFLiquidProof liquidProof = new FFLiquidProof(
            string(abi.encodePacked(IFFT(token).name(), " Liquid")),
            string(abi.encodePacked(IFFT(token).symbol(), " LIQUID")),
            address(this), 
            gasManager()
        );
        LaunchPool memory pool = LaunchPool(
            token,
            generator,
            address(liquidProof),
            timeLockVault,
            0,
            maxDeposit,
            startTime,
            endTime,
            poolParam.lockupDays,
            poolParam.totalSupply,
            sharePercent,
            0,
            false
        );
        poolId = nextId();
        _launchPools[poolId] = pool;

        emit RegisterPool(poolId, pool);
    }

    /**
     * @dev Update timeLockVault address
     * @param poolId - LaunchPool id
     * @param token - Token address
     * @param timeLockVault - TimeLockVault contract address
     * @notice The address can only be updated after the TimeLockVault contract is reviewed by the Outrun audit team.
     */
    function updateTimeLockVault(uint256 poolId, address token, address timeLockVault) external override onlyOwner {
        LaunchPool storage pool = _launchPools[poolId];
        require(pool.token == token, "Token mismatch");
        require(block.timestamp <= pool.endTime + pool.lockupDays * DAY, "Time exceeded");
        pool.timeLockVault = timeLockVault;

        emit UpdateTimeLockVault(poolId, timeLockVault);
    }

    receive() external payable {
        depositToTempFundPool();
    }
}
