// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./BaseScript.s.sol";
import {FF} from "../src/example/FF.sol";
import {FFGenerator} from "../src/example/FFGenerator.sol";

contract ExampleScript is BaseScript {
    uint256 public constant DAY = 24 * 3600;

    function run() public broadcaster {
        address owner = vm.envAddress("OWNER");
        address launcher = vm.envAddress("UETH_FFLAUNCHER");
        address fundReceiver = vm.envAddress("FUND_RECEIVER");

        FFGenerator generator = new FFGenerator(
            owner,
            launcher,
            fundReceiver
        );
        address generatorAddress = address(generator);
        FF ff = new FF(generatorAddress);
        address ffAddress = address(ff);
        generator.initialize(ffAddress);

        console.log("FF deployed on %s", ffAddress);
        console.log("FFGenerator deployed on %s", generatorAddress);
    }
}
