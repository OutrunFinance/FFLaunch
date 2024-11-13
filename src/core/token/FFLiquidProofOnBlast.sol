// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {FFLiquidProof} from"./FFLiquidProof.sol";
import {GasManagerable} from "../../blast/GasManagerable.sol";

/**
 * @title FFLaunch Liquid Proof Token On Blast
 */
contract FFLiquidProofOnBlast is FFLiquidProof, GasManagerable {
    constructor(
        string memory _name, 
        string memory _symbol, 
        uint8 _decimals, 
        address _launcher,
        address _gasManager
    ) FFLiquidProof(_name, _symbol, 18, _launcher) GasManagerable(_gasManager) {
    }
}
