//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

/**
 * @dev For OutswapV1Pair02
 */
library OutswapV1Library {
    error ZeroAddress();

    error IdenticalAddresses();

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, IdenticalAddresses());
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), ZeroAddress());
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            /* bytes32 public constant INIT_CODE_PAIR_HASH = keccak256(abi.encodePacked(type(OutswapV1Pair02).creationCode, abi.encode(gasManager))); */
                            hex"32048344e03cb0216d27b35afd5f3433cfaa5fe85288f7796b3727b248b7bc1c" // 1% init code hash
                        )
                    )
                )
            )
        );
    }
}
