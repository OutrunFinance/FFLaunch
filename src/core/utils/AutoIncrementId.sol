// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

abstract contract AutoIncrementId {
    uint256 public id = 0;

    function nextId() internal returns (uint256) {
        ++id;
        return id;
    }
}