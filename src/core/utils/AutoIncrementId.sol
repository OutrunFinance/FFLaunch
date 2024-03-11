// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

abstract contract AutoIncrementId {
    uint256 public count = 0;

    function nextId() public returns (uint256) {
        ++count;
        return count;
    }
}