// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {GasManagerable} from "../../blast/GasManagerable.sol";
import {FFLiquidProofOnBlast} from "../token/FFLiquidProofOnBlast.sol";
import {FFLauncher, IFFERC20, FFLiquidProof, ITokenGenerator} from "./FFLauncher.sol";

/**
 * @title FFLauncher On Blast
 */
contract FFLauncherOnBlast is FFLauncher, GasManagerable {
    constructor(
        address _owner,
        address _gasManager,
        address _UPT,
        address _revenuePool,
        address _outrunAMMRouter,
        address _outrunAMMFactory
    ) FFLauncher(_owner, _UPT, _revenuePool, _outrunAMMRouter, _outrunAMMFactory) GasManagerable(_gasManager) {
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
        uint128 startTime = poolParam.startTime;
        uint128 endTime = poolParam.endTime;
        uint256 sharePercent = poolParam.sharePercent;
        require(
            token != address(0) && 
            timeLockVault != address(0) &&
            startTime > currentTime && 
            endTime > currentTime && 
            endTime > startTime &&
            sharePercent > 0 && 
            sharePercent <= RATIO, 
            InvalidRegisterInfo()
        );

        address generator = poolParam.generator;
        ITokenGenerator tokenGenerator = ITokenGenerator(generator);
        require(tokenGenerator.token() == token && tokenGenerator.launcher() == address(this), InvalidTokenGenerator());

        uint256 currentPoolId = id;
        if (currentPoolId != 0) {
            require(currentTime > launchPools[currentPoolId].endTime, LastPoolNotEnd());
        }

        FFLiquidProofOnBlast liquidProof = new FFLiquidProofOnBlast(
            string(abi.encodePacked(IFFERC20(token).name(), " Liquid")),
            string(abi.encodePacked(IFFERC20(token).symbol(), " LIQUID")),
            18,
            address(this),
            gasManager
        );
        LaunchPool memory pool = LaunchPool(
            token,
            generator,
            address(liquidProof),
            timeLockVault,
            startTime,
            endTime,
            poolParam.lockupDays,
            poolParam.totalSupply,
            0,
            sharePercent,
            Stage.Preparation
        );
        poolId = nextId();
        launchPools[poolId] = pool;

        emit RegisterPool(poolId, pool);
    }
}
