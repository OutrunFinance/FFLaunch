source ../.env
forge clean && forge build
forge script FFLaunchScript.s.sol:FFLaunchScript --rpc-url blast_sepolia --broadcast --verify --ffi -vvvv
forge script ExampleScript.s.sol:ExampleScript --rpc-url blast_sepolia --broadcast --verify --ffi -vvvv