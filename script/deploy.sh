source ../.env
forge clean && forge build
# forge script FFLaunchScript.s.sol:FFLaunchScript --rpc-url blast_sepolia \
#     --priority-gas-price 300 --with-gas-price 1200000 \
#     --optimize --optimizer-runs 100000 \
#     --via-ir \
#     --broadcast --ffi -vvvv \
#     --verify 


forge script FFLaunchScript.s.sol:FFLaunchScript --rpc-url bsc_testnet \
    --with-gas-price 4000000000 \
    --optimize --optimizer-runs 100000 \
    --via-ir \
    --broadcast --ffi -vvvv \
    --verify 

#forge script ExampleScript.s.sol:ExampleScript --rpc-url blast_sepolia --broadcast --verify --ffi -vvvv