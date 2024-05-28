// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./BaseScript.s.sol";
import "../src/core/launcher/EthFFLauncher.sol";

contract FFLaunchScript is BaseScript {
    function run() public broadcaster {
        address owner = vm.envAddress("OWNER");
        address gasManager = vm.envAddress("GAS_MANAGER");
        address orETH = vm.envAddress("ORETH");
        address osETH = vm.envAddress("OSETH");

        address router = vm.envAddress("OUTSWAP_ROUTER");
        address factory = vm.envAddress("OUTSWAP_FACTORY");
        address stakeManager = vm.envAddress("ORETH_STAKE_MANAGER");
        EthFFLauncher ethLauncher = new EthFFLauncher(
            owner,
            orETH,
            osETH,
            gasManager,
            router,
            factory,
            stakeManager
        );
        address ethLauncherAddress = address(ethLauncher);

        console.log("EthFFLauncher deployed on %s", ethLauncherAddress);
    }
}
