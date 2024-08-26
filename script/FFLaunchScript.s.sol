// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./BaseScript.s.sol";
import "../src/core/launcher/ListaBnbFFLauncher.sol";

contract FFLaunchScript is BaseScript {
    address internal owner;
    address internal factory;
    address internal router;

    function run() public broadcaster {
        owner = vm.envAddress("OWNER");
        router = vm.envAddress("OUTRUN_AMM_ROUTER");
        factory = vm.envAddress("OUTRUN_AMM_FACTORY");

        _deployListaBNBLauncher();
    }

    function _deployListaBNBLauncher() internal {
        address launcherAddress = address(new ListaBnbFFLauncher(
            owner,
            vm.envAddress("SLISBNB"),
            vm.envAddress("OSLISBNB"),
            router,
            factory,
            vm.envAddress("LISTA_BNB_STAKE_MANAGER"),
            1e17
        ));

        console.log("ListaBnbFFLauncher deployed on %s", launcherAddress);
    }
}
