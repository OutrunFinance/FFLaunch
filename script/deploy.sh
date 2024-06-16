source ../.env
forge clean && forge build
forge script FFLaunchScript.s.sol:FFLaunchScript --rpc-url blast_sepolia \
    --priority-gas-price 300 --with-gas-price 1200000 \
    --optimize --optimizer-runs 100000 \
    --broadcast --verify --ffi -vvvv
#forge script ExampleScript.s.sol:ExampleScript --rpc-url blast_sepolia --broadcast --verify --ffi -vvvv