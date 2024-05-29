// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./BaseScript.s.sol";
import "../src/example/FF.sol";
import "../src/example/FFPoolCallee.sol";

contract ExampleScript is BaseScript {
    function run() public broadcaster {
        address owner = vm.envAddress("OWNER");
        address launcher = vm.envAddress("LAUNCHER");
        address gasManager = vm.envAddress("GAS_MANAGER");

        FFPoolCallee callee = new FFPoolCallee(
            owner,
            launcher,
            gasManager,
            block.timestamp + 3 days,
            block.timestamp + 6 days
        );
        address calleeAddress = address(callee);
        FF ff = new FF(launcher, calleeAddress, gasManager);
        address ffAddress = address(ff);
        callee.initialize(ffAddress);

        console.log("FFPoolCallee deployed on %s", calleeAddress);
        console.log("FF deployed on %s", ffAddress);
    }
}
