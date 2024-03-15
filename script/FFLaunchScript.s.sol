// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./BaseScript.s.sol";
import "../src/core/launcher/EthFFLauncher.sol";

contract FFLaunchScript is BaseScript {
    function run() public broadcaster {
        EthFFLauncher ethLauncher = new EthFFLauncher(
            0xcae21365145C467F8957607aE364fb29Ee073209,
            0xdaC9Ed63dada8A7005ce2c69F8FF8bF6C272a3D0,
            0x71e6A18c57F8794134A8e7088A61bBec22Cf1777,
            0x7a90a8d701584e9029c14b444a519eC33567F388,
            0x5A32bca57480f0B9910EcDB8DB854649b1E4F38C,
            0xC5Bb4e3C1e6143E6d70D65Ce51CA43f5da02dF24
        );
        address ethLauncherAddress = address(ethLauncher);

        console.log("EthFFLauncher deployed on %s", ethLauncherAddress);
    }
}
