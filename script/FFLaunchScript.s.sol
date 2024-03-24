// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./BaseScript.s.sol";
import "../src/core/launcher/EthFFLauncher.sol";

contract FFLaunchScript is BaseScript {
    function run() public broadcaster {
        address owner = vm.envAddress("OWNER");
        address gasManager = vm.envAddress("GAS_MANAGER");
        address RETH = vm.envAddress("RETH");
        address PETH = vm.envAddress("PETH");

        address router = vm.envAddress("OUTSWAP_ROUTER");
        address factory = vm.envAddress("OUTSWAP_FACTORY");
        address stakeManager = vm.envAddress("RETH_STAKE_MANAGER");
        EthFFLauncher ethLauncher = new EthFFLauncher(
            owner,
            RETH,
            PETH,
            gasManager,
            router,
            factory,
            stakeManager
        );
        address ethLauncherAddress = address(ethLauncher);

        console.log("EthFFLauncher deployed on %s", ethLauncherAddress);
    }
}
