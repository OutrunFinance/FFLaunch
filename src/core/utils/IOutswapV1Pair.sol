//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

interface IOutswapV1Pair {
    function claimMakerFee() external returns (uint256 makerFee);
}
