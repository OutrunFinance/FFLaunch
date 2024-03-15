// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "../core/token/FFT.sol";

/**
 * @title FF Token 
 */
contract FF is FFT {
    constructor(address _launcher, address _callee) FFT("Fair&Free", "FF", _launcher, _callee) {}
}