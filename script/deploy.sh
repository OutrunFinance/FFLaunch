source ../.env
forge clean && forge build
forge script FFLaunchScript.s.sol:FFLaunchScript --rpc-url blast_sepolia --broadcast --verify --ffi -vvvv