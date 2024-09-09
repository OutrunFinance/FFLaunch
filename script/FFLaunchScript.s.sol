// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./BaseScript.s.sol";
import "../src/core/launcher/FFLauncher.sol";

contract FFLaunchScript is BaseScript {
    address internal owner;
    address internal router;
    address internal factory;
    address internal UBNB;

    function run() public broadcaster {
        owner = vm.envAddress("OWNER");
        router = vm.envAddress("OUTRUN_AMM_ROUTER");
        factory = vm.envAddress("OUTRUN_AMM_FACTORY");
        UBNB = vm.envAddress("UBNB");

        _deployUBNBFFLauncher();
    }

    function _deployUBNBFFLauncher() internal {
        address UBNBFFLauncherAddress = address(new FFLauncher(
            owner,
            vm.envAddress("UBNB"),
            router,
            factory
        ));

        console.log("UBNBFFLauncher deployed on %s", UBNBFFLauncherAddress);
    }
}
