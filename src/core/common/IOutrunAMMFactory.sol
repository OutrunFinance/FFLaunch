//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

interface IOutrunAMMFactory {
    function pairImplementation() external view returns (address);
}
