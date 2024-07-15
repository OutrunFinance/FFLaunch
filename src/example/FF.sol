// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import "../core/token/FFERC20.sol";

/**
 * @title FF Token 
 */
contract FF is FFERC20 {
    constructor(address _launcher, address _generator, address _gasManager) FFERC20("Fair&Free", "FF", _launcher, _generator, _gasManager) {}
}