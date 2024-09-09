// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

abstract contract AutoIncrementId {
    uint256 public id = 0;

    function nextId() internal returns (uint256) {
        ++id;
        return id;
    }
}