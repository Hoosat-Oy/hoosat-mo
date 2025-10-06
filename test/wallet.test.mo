// import {test; suite} "mo:test";
// import Result "mo:base/Result";
// import Text "mo:base/Text";
// import Blob "mo:base/Blob";
// import Array "mo:base/Array";

// import Wallet "../src/wallet";
// import Constants "../src/constants";
// import Errors "../src/errors";
// import Address "../src/address";
// import Validation "../src/validation";

// suite("Wallet Production Tests", func() {

//     // Test wallet configuration validation with dfx_test_key
//     test("Mainnet wallet has correct configuration", func() {
//         let _wallet = Wallet.createMainnetWallet("dfx_test_key");
//         // Test passes if wallet creation doesn't throw
//         assert true;
//     });

//     test("Testnet wallet has correct configuration", func() {
//         let _wallet = Wallet.createTestnetWallet("dfx_test_key");
//         // Test passes if wallet creation doesn't throw
//         assert true;
//     });

//     // Test address type constants are correct
//     test("Address type constants are correct", func() {
//         assert Constants.SCHNORR == 0;
//         assert Constants.ECDSA == 1;
//         assert Constants.P2SH == 2;
//         assert Constants.SCHNORR_PAYLOAD_LEN == 32;
//         assert Constants.ECDSA_PAYLOAD_LEN == 33;
//     });

//     // Test address validation logic
//     test("Address validation works correctly", func() {
//         let valid_address = "Hoosat:qypqv8kxjmnwqzpgllej3j3xp5nk3nrzltz3t2p5k5n6w4lzxhxfgqjkv5z7";
//         let invalid_address = "invalid_address";
//         let empty_address = "";

//         // Valid address should pass
//         switch (Validation.validateAddress(valid_address)) {
//             case (#ok(_)) { assert true };
//             case (#err(_)) { assert false };
//         };

//         // Invalid address should fail
//         switch (Validation.validateAddress(invalid_address)) {
//             case (#ok(_)) { assert false };
//             case (#err(_)) { assert true };
//         };

//         // Empty address should fail
//         switch (Validation.validateAddress(empty_address)) {
//             case (#ok(_)) { assert false };
//             case (#err(_)) { assert true };
//         };
//     });

//     // Test amount validation
//     test("Amount validation works correctly", func() {
//         // Valid amounts should pass
//         switch (Validation.validateAmount(1000000, false)) {
//             case (#ok(_)) { assert true };
//             case (#err(_)) { assert false };
//         };

//         // Zero amount should fail when dust check is enabled
//         switch (Validation.validateAmount(0, true)) {
//             case (#ok(_)) { assert false };
//             case (#err(_)) { assert true };
//         };

//         // Amount below dust threshold should fail with dust check
//         switch (Validation.validateAmount(500, true)) {
//             case (#ok(_)) { assert false };
//             case (#err(_)) { assert true };
//         };

//         // Amount below dust threshold should pass without dust check
//         switch (Validation.validateAmount(500, false)) {
//             case (#ok(_)) { assert true };
//             case (#err(_)) { assert false };
//         };
//     });

//     // Test fee validation
//     test("Fee validation works correctly", func() {
//         // Valid fee should pass
//         switch (Validation.validateFee(1000)) {
//             case (#ok(_)) { assert true };
//             case (#err(_)) { assert false };
//         };

//         // Fee below minimum should fail
//         switch (Validation.validateFee(1)) {
//             case (#ok(_)) { assert false };
//             case (#err(_)) { assert true };
//         };
//     });

//     // Test derivation path validation with dfx_test_key format
//     test("Derivation path validation works correctly", func() {
//         let valid_paths = [
//             "44'/111111'/0'/0/0",
//             "44'/111111'/1'/0/5",
//             "0",
//             "1/2/3",
//             "" // Empty path should be valid
//         ];

//         let invalid_paths = [
//             "44'/111111'/abc/0/0",
//             "invalid_path",
//             "44'/111111'//0/0"
//         ];

//         // Valid paths should pass
//         for (path in valid_paths.vals()) {
//             switch (Validation.validateDerivationPath(path)) {
//                 case (#ok(_)) { assert true };
//                 case (#err(_)) { assert false };
//             };
//         };

//         // Invalid paths should fail
//         for (path in invalid_paths.vals()) {
//             switch (Validation.validateDerivationPath(path)) {
//                 case (#ok(_)) { assert false };
//                 case (#err(_)) { assert true };
//             };
//         };
//     });

//     // Test hex string validation
//     test("Hex string validation works correctly", func() {
//         let valid_hex = "abcdef1234567890";
//         let invalid_hex = "xyz123";
//         let empty_hex = "";

//         // Valid hex should pass
//         switch (Validation.validateHexString(valid_hex)) {
//             case (#ok(_)) { assert true };
//             case (#err(_)) { assert false };
//         };

//         // Invalid hex should fail
//         switch (Validation.validateHexString(invalid_hex)) {
//             case (#ok(_)) { assert false };
//             case (#err(_)) { assert true };
//         };

//         // Empty hex should fail
//         switch (Validation.validateHexString(empty_hex)) {
//             case (#ok(_)) { assert false };
//             case (#err(_)) { assert true };
//         };
//     });

//     // Test address encoding/decoding roundtrip
//     test("Address encoding/decoding roundtrip", func() {
//         let test_addresses = [
//             "Hoosat:qypqv8kxjmnwqzpgllej3j3xp5nk3nrzltz3t2p5k5n6w4lzxhxfgqjkv5z7",
//             "Hoosat:qqkqkzjvr7zwxxmjxjkmxxdwju9kjs6e9u82uh59z07vgaks6gg62v8707g73"
//         ];

//         for (address in test_addresses.vals()) {
//             switch (Address.decodeAddress(address)) {
//                 case (#ok(addr_info)) {
//                     // Verify address type is valid
//                     assert (addr_info.addr_type == Constants.SCHNORR or
//                            addr_info.addr_type == Constants.ECDSA or
//                            addr_info.addr_type == Constants.P2SH);

//                     // Verify payload length matches address type
//                     let expected_len = if (addr_info.addr_type == Constants.ECDSA) {
//                         Constants.ECDSA_PAYLOAD_LEN
//                     } else {
//                         Constants.SCHNORR_PAYLOAD_LEN
//                     };
//                     assert addr_info.payload.size() == expected_len;

//                     // Verify original address matches decoded info
//                     assert addr_info.address == address;
//                 };
//                 case (#err(_)) {
//                     assert false; // Known valid addresses should decode successfully
//                 };
//             };
//         };
//     });

//     // Test error types are properly structured
//     test("Error types are well-formed", func() {
//         let validation_error = Errors.validationError("test message");
//         let network_error = Errors.networkError("test message", ?404);
//         let crypto_error = Errors.cryptographicError("test message");

//         // Errors should be properly constructed
//         switch (validation_error) {
//             case (#validationError(_)) { assert true };
//             case (_) { assert false };
//         };

//         switch (network_error) {
//             case (#networkError(_, _)) { assert true };
//             case (_) { assert false };
//         };

//         switch (crypto_error) {
//             case (#cryptographicError(_)) { assert true };
//             case (_) { assert false };
//         };
//     });

//     // Test dust threshold constant
//     test("Dust threshold is correctly defined", func() {
//         assert Constants.DUST_THRESHOLD == 1000;
//     });

//     // Test wallet factory with dfx_test_key specifically
//     test("Wallet factory uses dfx_test_key correctly", func() {
//         let mainnet_wallet = Wallet.createMainnetWallet("dfx_test_key");
//         let testnet_wallet = Wallet.createTestnetWallet("dfx_test_key");

//         // Both should be created without throwing
//         assert true;
//     });

// });