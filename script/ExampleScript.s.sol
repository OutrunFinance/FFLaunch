// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./BaseScript.s.sol";
import "../src/example/FF.sol";
import "../src/example/FFGenerator.sol";

contract ExampleScript is BaseScript {
    uint256 public constant DAY = 24 * 3600;

    function run() public broadcaster {
        address owner = vm.envAddress("OWNER");
        address launcher = vm.envAddress("LISTA_BNB_FFLAUNCHER");

        FFGenerator generator = new FFGenerator(
            owner,
            launcher
        );
        address generatorAddress = address(generator);
        FF ff = new FF(generatorAddress);
        address ffAddress = address(ff);
        generator.initialize(ffAddress);

        console.log("FFGenerator deployed on %s", generatorAddress);
        console.log("FF deployed on %s", ffAddress);
    }
}
