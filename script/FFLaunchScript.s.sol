// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./BaseScript.s.sol";
import "../src/core/launcher/EthFFLauncher.sol";
import "../src/core/launcher/UsdbFFLauncher.sol";

contract FFLaunchScript is BaseScript {
    address internal owner;
    address internal gasManager;
    address internal factory;
    address internal router;

    function run() public broadcaster {
        owner = vm.envAddress("OWNER");
        gasManager = vm.envAddress("GAS_MANAGER");
        factory = vm.envAddress("OUTSWAP_FACTORY");
        router = vm.envAddress("OUTSWAP_ROUTER");

        _deployEthLauncher();
        _deployUsdbLauncher();
    }

    function _deployEthLauncher() internal {
        address ethLauncherAddress = address(new EthFFLauncher(
            owner,
            vm.envAddress("ORETH"),
            vm.envAddress("OSETH"),
            gasManager,
            factory,
            router,
            vm.envAddress("ORETH_STAKE_MANAGER"),
            5 * 10 ** 16
        ));

        console.log("EthFFLauncher deployed on %s", ethLauncherAddress);
    }

    function _deployUsdbLauncher() internal {
        address usdbLauncherAddress = address(new UsdbFFLauncher(
            owner,
            vm.envAddress("ORUSD"),
            vm.envAddress("OSUSD"),
            gasManager,
            factory,
            router,
            vm.envAddress("ORUSD_STAKE_MANAGER"),
            100 * 10 ** 18
        ));

        console.log("UsdbFFLauncher deployed on %s", usdbLauncherAddress);
    }
}
