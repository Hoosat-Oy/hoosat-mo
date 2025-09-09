#!/bin/bash

# Exit on error
set -e

echo "--- Deploying Canister ---"
dfx deploy

echo "--- Testing Connection to Kaspa Testnet ---"
dfx canister call kaspa_test_broadcast testConnection '(variant { testnet })'

echo "--- Running Broadcast Test ---"
# This function will create and broadcast a hardcoded transaction
dfx canister call kaspa_test_broadcast runBroadcastTest

echo "--- Test Complete ---"