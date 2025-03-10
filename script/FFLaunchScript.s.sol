// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./BaseScript.s.sol";
import { IOutrunDeployer } from "./IOutrunDeployer.sol";
import {FFLauncher} from "../src/core/launcher/FFLauncher.sol";
import {FFLiquidProof} from "../src/core/token/FFLiquidProof.sol";

contract FFLaunchScript is BaseScript {
    address internal owner;
    address internal router;
    address internal factory;
    address internal UETH;
    address internal OUTRUN_DEPLOYER;
    address internal POL_IMPLEMENTATION;

    function run() public broadcaster {
        owner = vm.envAddress("OWNER");
        router = vm.envAddress("OUTRUN_AMM_ROUTER");
        factory = vm.envAddress("OUTRUN_AMM_FACTORY");
        UETH = vm.envAddress("UETH");
        OUTRUN_DEPLOYER = vm.envAddress("OUTRUN_DEPLOYER");
        POL_IMPLEMENTATION = vm.envAddress("POL_IMPLEMENTATION");

        _deployPOLImplementation(0);
        _deployUETHFFLauncher();
    }

    function _deployPOLImplementation(uint256 nonce) internal {
        address deployedPolImplementation = IOutrunDeployer(OUTRUN_DEPLOYER).deploy(
            keccak256(abi.encodePacked("POLImplementation", nonce)), type(FFLiquidProof).creationCode
        );

        console.log("POLImplementation deployed on %s", deployedPolImplementation);
    }

    function _deployUETHFFLauncher() internal {
        address UETHFFLauncherAddress = address(new FFLauncher(
            owner,
            UETH,
            router,
            factory,
            POL_IMPLEMENTATION
        ));

        console.log("UETHFFLauncher deployed on %s", UETHFFLauncherAddress);
    }
}
