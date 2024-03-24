// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./BaseScript.s.sol";
import "../src/core/launcher/EthFFLauncher.sol";

contract FFLaunchScript is BaseScript {
    function run() public broadcaster {
        EthFFLauncher ethLauncher = new EthFFLauncher(
            0xcae21365145C467F8957607aE364fb29Ee073209,
            0x8921b78E6b521dF5F55eF41e1787100BD43c1366,
            0xB4A206bF720B27551Afc70be203562caEE0AEd45,
            0x1E7EC127f64d0dB0670d2F084Cdc02e74A6dCcc5,
            0x56e36C75899Ad410f90582c0AD2354eAE8F6952D,
            0x0F487DF3E7C641F422a0a28Dc419C416e9fda95E
        );
        address ethLauncherAddress = address(ethLauncher);

        console.log("EthFFLauncher deployed on %s", ethLauncherAddress);
    }
}
