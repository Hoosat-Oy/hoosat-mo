
// import Array "mo:base/Array";
// import Blob "mo:base/Blob";
// import Text "mo:base/Text";
// import Nat8 "mo:base/Nat8";

// import Address "../src/kaspa/address";

// // Constants for address types and lengths
// let SCHNORR = 0;
// let ECDSA = 1;
// let P2SH = 2;
// let SCHNORR_ADDRESS_LEN = 64; // Adjust based on actual length
// let ECDSA_ADDRESS_LEN = 65;   // Adjust based on actual length

// // Helper function to convert hex array to Blob
// func hexToBlob(hex : [Nat8]) : Blob {
//     Blob.fromArray(hex);
// };

// // Test for Schnorr address generation
// func test_schnorr_address_from_public_key() {
//     let public_key1 : [Nat8] = [
//         0x21, 0xEB, 0x0C, 0x42, 0x70, 0x12, 0x8B, 0x16, 0xC9, 0x3C, 0x5F, 0x0D, 0xAC, 0x48, 0xD5, 0x60,
//         0x51, 0xA6, 0x23, 0x7D, 0xAE, 0x99, 0x7B, 0x58, 0x91, 0x26, 0x95, 0x05, 0x28, 0x18, 0xE3, 0x48,
//         0xB0, 0xA8, 0x95, 0xCB, 0xD0, 0xC9, 0x3A, 0x11, 0xEE, 0x7A, 0xFA, 0xC7, 0x45, 0x92, 0x9D, 0x96,
//         0xA4, 0x64, 0x2A, 0x71, 0x83, 0x1F, 0x54, 0xA7, 0x37, 0x78, 0x93, 0xAF, 0x71, 0xA2, 0xE2, 0xAE
//     ];
//     let expected_address1 = "kaspa:qqs7krzzwqfgk9kf830smtzg64s9rf3r0khfj76cjynf2pfgrr35saatu88xq";
//     let address1 = Address.address_from_pubkey(hexToBlob(public_key1), SCHNORR, SCHNORR_ADDRESS_LEN);
//     assert Text.equal(address1, expected_address1);

//     let public_key2 : [Nat8] = [
//         0xFA, 0x2B, 0x85, 0x72, 0xB6, 0x18, 0x36, 0x2A, 0x26, 0x12, 0x8D, 0xB3, 0x88, 0xF0, 0x4E, 0xD1,
//         0xA9, 0x5C, 0xCC, 0xD8, 0xE1, 0x89, 0xF9, 0xC1, 0xBD, 0x6C, 0x57, 0x66, 0x8B, 0x11, 0xB2, 0xD7,
//         0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
//         0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
//     ];
//     let expected_address2 = "kaspa:qrazhptjkcvrv23xz2xm8z8sfmg6jhxvmrscn7wph4k9we5tzxedwfxf0v6f8";
//     let address2 = Address.address_from_pubkey(hexToBlob(public_key2), SCHNORR, SCHNORR_ADDRESS_LEN);
//     assert Text.equal(address2, expected_address2);
// };

// // Test for P2SH address generation
// func test_p2sh_address_from_public_key() {
//     let public_key : [Nat8] = [
//         0xF3, 0x80, 0x31, 0xF6, 0x1C, 0xA2, 0x3D, 0x70, 0x84, 0x4F, 0x63, 0xA4, 0x77, 0xD0, 0x7F, 0x0B,
//         0x2C, 0x2D, 0xEC, 0xAB, 0x90, 0x7C, 0x2E, 0x09, 0x6E, 0x54, 0x8B, 0x0E, 0x08, 0x72, 0x1C, 0x79,
//         0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
//         0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
//     ];
//     let expected_address = "kaspa:precqv0krj3r6uyyfa36ga7s0u9jct0v4wg8ctsfde2gkrsgwgw8jgxfzfc98";
//     let address = Address.address_from_pubkey(hexToBlob(public_key), P2SH, SCHNORR_ADDRESS_LEN);
//     assert Text.equal(address, expected_address);
// };

// // Test for ECDSA address generation
// func test_ecdsa_address_from_public_key() {
//     let public_key_even : [Nat8] = [
//         0xD5, 0xFD, 0xC7, 0xAD, 0x11, 0xA6, 0x5D, 0x0B, 0xBE, 0x78, 0x82, 0xFC, 0x3D, 0xBC, 0x91, 0xB5,
//         0x86, 0x1D, 0x18, 0x2D, 0xCC, 0xE7, 0x9F, 0x7C, 0x1B, 0xE5, 0xBF, 0xD3, 0x0A, 0x67, 0x7C, 0xD6,
//         0xC5, 0x62, 0xAD, 0x66, 0xAB, 0xCD, 0xB1, 0xEC, 0x02, 0xF3, 0xE4, 0xB0, 0x7C, 0x11, 0xBC, 0x5A,
//         0x94, 0xA6, 0x85, 0xFE, 0xDB, 0x5D, 0x55, 0x87, 0x07, 0x6E, 0x48, 0xB1, 0x2D, 0xA6, 0xC2, 0x82
//     ];
//     let expected_address_even = "kaspa:qypdtlw845g6vhgtheug9lpahjgmtpsarqkueeul0sd7t07npfnhe4s7fd82n0v";
//     let address_even = Address.address_from_pubkey(hexToBlob(public_key_even), ECDSA, ECDSA_ADDRESS_LEN);
//     assert Text.equal(address_even, expected_address_even);

//     let public_key_odd : [Nat8] = [
//         0xE3, 0x10, 0x0D, 0x85, 0xEF, 0xAE, 0x93, 0xE0, 0xC2, 0xFC, 0x65, 0x4B, 0x2F, 0x0C, 0x33, 0x58,
//         0x4F, 0x21, 0x3A, 0x3F, 0xDF, 0xFD, 0x02, 0x3C, 0x82, 0x12, 0x77, 0xB2, 0x17, 0x89, 0xE0, 0x64,
//         0xE0, 0x6B, 0x45, 0x4F, 0x5C, 0xBA, 0x0E, 0xFF, 0x1C, 0xE8, 0x01, 0xD3, 0x83, 0x5C, 0x39, 0xEC,
//         0x01, 0xCA, 0x94, 0x9C, 0xA8, 0x77, 0xC0, 0xB5, 0x5B, 0xBD, 0xEC, 0xA8, 0xFF, 0x84, 0x91, 0xD9
//     ];
//     let expected_address_odd = "kaspa:qyp7xyqdshh6aylqct7x2je0pse4snep8glallgz8jppyaajz7y7qeq4x79fq4z";
//     let address_odd = Address.address_from_pubkey(hexToBlob(public_key_odd), ECDSA, ECDSA_ADDRESS_LEN);
//     assert Text.equal(address_odd, expected_address_odd);
// };

// // Test for invalid address type
// func test_invalid_type() {
//     let public_key : [Nat8] = [0];
//     let result = Address.address_from_pubkey(hexToBlob(public_key), -1, 1);
//     assert result == "";
// };

// // Test for Schnorr key compression
// func test_compress_address_schnorr() {
//     let public_key : [Nat8] = [
//         0xF3, 0x80, 0x31, 0xF6, 0x1C, 0xA2, 0x3D, 0x70, 0x84, 0x4F, 0x63, 0xA4, 0x77, 0xD0, 0x7F, 0x0B,
//         0x2C, 0x2D, 0xEC, 0xAB, 0x90, 0x7C, 0x2E, 0x09, 0x6E, 0x54, 0x8B, 0x0E, 0x08, 0x72, 0x1C, 0x79,
//         0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
//         0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
//     ];
//     let expected : [Nat8] = Array.subArray(public_key, 0, 32);
//     let compressed = Address.compress_public_key(hexToBlob(public_key), SCHNORR, 32);
//     assert compressed == hexToBlob(expected);
// };

// // Test for ECDSA key compression
// func test_compress_address_ecdsa() {
//     let public_key_even : [Nat8] = [
//         0xD5, 0xFD, 0xC7, 0xAD, 0x11, 0xA6, 0x5D, 0x0B, 0xBE, 0x78, 0x82, 0xFC, 0x3D, 0xBC, 0x91, 0xB5,
//         0x86, 0x1D, 0x18, 0x2D, 0xCC, 0xE7, 0x9F, 0x7C, 0x1B, 0xE5, 0xBF, 0xD3, 0x0A, 0x67, 0x7C, 0xD6,
//         0xC5, 0x62, 0xAD, 0x66, 0xAB, 0xCD, 0xB1, 0xEC, 0x02, 0xF3, 0xE4, 0xB0, 0x7C, 0x11, 0xBC, 0x5A,
//         0x94, 0xA6, 0x85, 0xFE, 0xDB, 0x5D, 0x55, 0x87, 0x07, 0x6E, 0x48, 0xB1, 0x2D, 0xA6, 0xC2, 0x82
//     ];
//     let expected_even : [Nat8] = Array.append([0x02 : Nat8], Array.subArray(public_key_even, 0, 32));
//     let compressed_even = Address.compress_public_key(hexToBlob(public_key_even), ECDSA, 33);
//     assert compressed_even == hexToBlob(expected_even);

//     let public_key_odd : [Nat8] = [
//         0xE3, 0x10, 0x0D, 0x85, 0xEF, 0xAE, 0x93, 0xE0, 0xC2, 0xFC, 0x65, 0x4B, 0x2F, 0x0C, 0x33, 0x58,
//         0x4F, 0x21, 0x3A, 0x3F, 0xDF, 0xFD, 0x02, 0x3C, 0x82, 0x12, 0x77, 0xB2, 0x17, 0x89, 0xE0, 0x64,
//         0xE0, 0x6B, 0x45, 0x4F, 0x5C, 0xBA, 0x0E, 0xFF, 0x1C, 0xE8, 0x01, 0xD3, 0x83, 0x5C, 0x39, 0xEC,
//         0x01, 0xCA, 0x94, 0x9C, 0xA8, 0x77, 0xC0, 0xB5, 0x5B, 0xBD, 0xEC, 0xA8, 0xFF, 0x84, 0x91, 0xD9
//     ];
//     let expected_odd : [Nat8] = Array.append([0x03 : Nat8], Array.subArray(public_key_odd, 0, 32));
//     let compressed_odd = Address.compress_public_key(hexToBlob(public_key_odd), ECDSA, 33);
//     assert compressed_odd == hexToBlob(expected_odd);
// };

// // Test for invalid compression
// func test_invalid_compress_address() {
//     let public_key : [Nat8] = [
//         0xE3, 0x10, 0x0D, 0x85, 0xEF, 0xAE, 0x93, 0xE0, 0xC2, 0xFC, 0x65, 0x4B, 0x2F, 0x0C, 0x33, 0x58,
//         0x4F, 0x21, 0x3A, 0x3F, 0xDF, 0xFD, 0x02, 0x3C, 0x82, 0x12, 0x77, 0xB2, 0x17, 0x89, 0xE0, 0x64,
//         0xE0, 0x6B, 0x45, 0x4F, 0x5C, 0xBA, 0x0E, 0xFF, 0x1C, 0xE8, 0x01, 0xD3, 0x83, 0x5C, 0x39, 0xEC,
//         0x01, 0xCA, 0x94, 0x9C, 0xA8, 0x77, 0xC0, 0xB5, 0x5B, 0xBD, 0xEC, 0xA8, 0xFF, 0x84, 0x91, 0xD9
//     ];
//     let result_schnorr = Address.compress_public_key(hexToBlob(public_key), SCHNORR, 31); // Too small
//     assert result_schnorr == Blob.fromArray([]);
//     let result_ecdsa = Address.compress_public_key(hexToBlob(public_key), ECDSA, 32); // Too small
//     assert result_ecdsa == Blob.fromArray([]);
// };

// // Run all tests
// func run_tests() {
//     test_schnorr_address_from_public_key();
//     test_p2sh_address_from_public_key();
//     test_ecdsa_address_from_public_key();
//     test_invalid_type();
//     test_compress_address_schnorr();
//     test_compress_address_ecdsa();
//     test_invalid_compress_address();
// };

// // Execute tests
// run_tests();











// import Array "mo:base/Array";
// import Blob "mo:base/Blob";
// import Text "mo:base/Text";
// import Nat8 "mo:base/Nat8";
// import Debug "mo:base/Debug";
// import Principal "mo:base/Principal";
// import Cycles "mo:base/ExperimentalCycles";
// import Error "mo:base/Error";

// import Address "../src/kaspa/address";


// persistent actor {

// // Constants for address types and lengths
// let SCHNORR = 0;
// let ECDSA = 1;
// let P2SH = 2;
// let SCHNORR_ADDRESS_LEN = 64; // Adjust based on actual length
// let ECDSA_ADDRESS_LEN = 65;   // Adjust based on actual length

// // Helper function to convert hex array to Blob
// func hexToBlob(hex : [Nat8]) : Blob {
//     Blob.fromArray(hex);
// };

// // Helper function to convert compressed public key to uncompressed (simplified)
// func to_uncompressed_public_key(pubkey : Blob) : ?Blob {
//     let bytes = Blob.toArray(pubkey);
//     Debug.print("Raw public key bytes: " # debug_show(bytes) # ", size: " # debug_show(bytes.size()));
//     if (bytes.size() == 65 and bytes[0] == 0x04) {
//         // Already uncompressed
//         Debug.print("Public key is uncompressed (65 bytes)");
//         ?pubkey
//     } else if (bytes.size() == 33 and (bytes[0] == 0x02 or bytes[0] == 0x03)) {
//         // Compressed: Return as-is for testing if address_from_pubkey supports it
//         Debug.print("Public key is compressed (33 bytes)");
//         ?pubkey
//     } else {
//         Debug.print("Invalid public key format, size: " # debug_show(bytes.size()));
//         null
//     }
// };

//   public func runTests() : async () {
//     Debug.print("Running address tests");

//     // Test for Schnorr address generation
//     func test_schnorr_address_from_public_key() {
//         Debug.print("Testing Schnorr address generation");
//         let public_key1 : [Nat8] = [
//             0x21, 0xEB, 0x0C, 0x42, 0x70, 0x12, 0x8B, 0x16, 0xC9, 0x3C, 0x5F, 0x0D, 0xAC, 0x48, 0xD5, 0x60,
//             0x51, 0xA6, 0x23, 0x7D, 0xAE, 0x99, 0x7B, 0x58, 0x91, 0x26, 0x95, 0x05, 0x28, 0x18, 0xE3, 0x48,
//             0xB0, 0xA8, 0x95, 0xCB, 0xD0, 0xC9, 0x3A, 0x11, 0xEE, 0x7A, 0xFA, 0xC7, 0x45, 0x92, 0x9D, 0x96,
//             0xA4, 0x64, 0x2A, 0x71, 0x83, 0x1F, 0x54, 0xA7, 0x37, 0x78, 0x93, 0xAF, 0x71, 0xA2, 0xE2, 0xAE
//         ];
//         let expected_address1 = "kaspa:qqs7krzzwqfgk9kf830smtzg64s9rf3r0khfj76cjynf2pfgrr35saatu88xq";
//         let address1 = Address.address_from_pubkey(hexToBlob(public_key1), SCHNORR, SCHNORR_ADDRESS_LEN);
//         Debug.print("Schnorr address1: " # address1);
//         assert Text.equal(address1, expected_address1);

//         let public_key2 : [Nat8] = [
//             0xFA, 0x2B, 0x85, 0x72, 0xB6, 0x18, 0x36, 0x2A, 0x26, 0x12, 0x8D, 0xB3, 0x88, 0xF0, 0x4E, 0xD1,
//             0xA9, 0x5C, 0xCC, 0xD8, 0xE1, 0x89, 0xF9, 0xC1, 0xBD, 0x6C, 0x57, 0x66, 0x8B, 0x11, 0xB2, 0xD7,
//             0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
//             0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
//         ];
//         let expected_address2 = "kaspa:qrazhptjkcvrv23xz2xm8z8sfmg6jhxvmrscn7wph4k9we5tzxedwfxf0v6f8";
//         let address2 = Address.address_from_pubkey(hexToBlob(public_key2), SCHNORR, SCHNORR_ADDRESS_LEN);
//         Debug.print("Schnorr address2: " # address2);
//         assert Text.equal(address2, expected_address2);
//     };

//     // Test for P2SH address generation
//     func test_p2sh_address_from_public_key() {
//         Debug.print("Testing P2SH address generation");
//         let public_key : [Nat8] = [
//             0xF3, 0x80, 0x31, 0xF6, 0x1C, 0xA2, 0x3D, 0x70, 0x84, 0x4F, 0x63, 0xA4, 0x77, 0xD0, 0x7F, 0x0B,
//             0x2C, 0x2D, 0xEC, 0xAB, 0x90, 0x7C, 0x2E, 0x09, 0x6E, 0x54, 0x8B, 0x0E, 0x08, 0x72, 0x1C, 0x79,
//             0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
//             0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
//         ];
//         let expected_address = "kaspa:precqv0krj3r6uyyfa36ga7s0u9jct0v4wg8ctsfde2gkrsgwgw8jgxfzfc98";
//         let address = Address.address_from_pubkey(hexToBlob(public_key), P2SH, SCHNORR_ADDRESS_LEN);
//         Debug.print("P2SH address: " # address);
//         assert Text.equal(address, expected_address);
//     };

//     // Test for ECDSA address generation
//     func test_ecdsa_address_from_public_key() {
//         Debug.print("Testing ECDSA address generation");
//         let public_key_even : [Nat8] = [
//             0xD5, 0xFD, 0xC7, 0xAD, 0x11, 0xA6, 0x5D, 0x0B, 0xBE, 0x78, 0x82, 0xFC, 0x3D, 0xBC, 0x91, 0xB5,
//             0x86, 0x1D, 0x18, 0x2D, 0xCC, 0xE7, 0x9F, 0x7C, 0x1B, 0xE5, 0xBF, 0xD3, 0x0A, 0x67, 0x7C, 0xD6,
//             0xC5, 0x62, 0xAD, 0x66, 0xAB, 0xCD, 0xB1, 0xEC, 0x02, 0xF3, 0xE4, 0xB0, 0x7C, 0x11, 0xBC, 0x5A,
//             0x94, 0xA6, 0x85, 0xFE, 0xDB, 0x5D, 0x55, 0x87, 0x07, 0x6E, 0x48, 0xB1, 0x2D, 0xA6, 0xC2, 0x82
//         ];
//         let expected_address_even = "kaspa:qypdtlw845g6vhgtheug9lpahjgmtpsarqkueeul0sd7t07npfnhe4s7fd82n0v";
//         let address_even = Address.address_from_pubkey(hexToBlob(public_key_even), ECDSA, ECDSA_ADDRESS_LEN);
//         Debug.print("ECDSA address even: " # address_even);
//         assert Text.equal(address_even, expected_address_even);

//         let public_key_odd : [Nat8] = [
//             0xE3, 0x10, 0x0D, 0x85, 0xEF, 0xAE, 0x93, 0xE0, 0xC2, 0xFC, 0x65, 0x4B, 0x2F, 0x0C, 0x33, 0x58,
//             0x4F, 0x21, 0x3A, 0x3F, 0xDF, 0xFD, 0x02, 0x3C, 0x82, 0x12, 0x77, 0xB2, 0x17, 0x89, 0xE0, 0x64,
//             0xE0, 0x6B, 0x45, 0x4F, 0x5C, 0xBA, 0x0E, 0xFF, 0x1C, 0xE8, 0x01, 0xD3, 0x83, 0x5C, 0x39, 0xEC,
//             0x01, 0xCA, 0x94, 0x9C, 0xA8, 0x77, 0xC0, 0xB5, 0x5B, 0xBD, 0xEC, 0xA8, 0xFF, 0x84, 0x91, 0xD9
//         ];
//         let expected_address_odd = "kaspa:qyp7xyqdshh6aylqct7x2je0pse4snep8glallgz8jppyaajz7y7qeq4x79fq4z";
//         let address_odd = Address.address_from_pubkey(hexToBlob(public_key_odd), ECDSA, ECDSA_ADDRESS_LEN);
//         Debug.print("ECDSA address odd: " # address_odd);
//         assert Text.equal(address_odd, expected_address_odd);
//     };

//     // Test for invalid address type
//     func test_invalid_type() {
//         Debug.print("Testing invalid address type");
//         let public_key : [Nat8] = [0];
//         let result = Address.address_from_pubkey(hexToBlob(public_key), -1, 1);
//         Debug.print("Invalid type address: " # result);
//         assert result == "";
//     };

//     // Test for Schnorr key compression
//     func test_compress_address_schnorr() {
//         Debug.print("Testing Schnorr key compression");
//         let public_key : [Nat8] = [
//             0xF3, 0x80, 0x31, 0xF6, 0x1C, 0xA2, 0x3D, 0x70, 0x84, 0x4F, 0x63, 0xA4, 0x77, 0xD0, 0x7F, 0x0B,
//             0x2C, 0x2D, 0xEC, 0xAB, 0x90, 0x7C, 0x2E, 0x09, 0x6E, 0x54, 0x8B, 0x0E, 0x08, 0x72, 0x1C, 0x79,
//             0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
//             0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
//         ];
//         let expected : [Nat8] = Array.subArray(public_key, 0, 32);
//         let compressed = Address.compress_public_key(hexToBlob(public_key), SCHNORR, 32);
//         Debug.print("Schnorr compressed key: " # debug_show(Blob.toArray(compressed)));
//         assert compressed == hexToBlob(expected);
//     };

//     // Test for ECDSA key compression
//     func test_compress_address_ecdsa() {
//         Debug.print("Testing ECDSA key compression");
//         let public_key_even : [Nat8] = [
//             0xD5, 0xFD, 0xC7, 0xAD, 0x11, 0xA6, 0x5D, 0x0B, 0xBE, 0x78, 0x82, 0xFC, 0x3D, 0xBC, 0x91, 0xB5,
//             0x86, 0x1D, 0x18, 0x2D, 0xCC, 0xE7, 0x9F, 0x7C, 0x1B, 0xE5, 0xBF, 0xD3, 0x0A, 0x67, 0x7C, 0xD6,
//             0xC5, 0x62, 0xAD, 0x66, 0xAB, 0xCD, 0xB1, 0xEC, 0x02, 0xF3, 0xE4, 0xB0, 0x7C, 0x11, 0xBC, 0x5A,
//             0x94, 0xA6, 0x85, 0xFE, 0xDB, 0x5D, 0x55, 0x87, 0x07, 0x6E, 0x48, 0xB1, 0x2D, 0xA6, 0xC2, 0x82
//         ];
//         let expected_even : [Nat8] = Array.append([0x02 : Nat8], Array.subArray(public_key_even, 0, 32));
//         let compressed_even = Address.compress_public_key(hexToBlob(public_key_even), ECDSA, 33);
//         Debug.print("ECDSA compressed even key: " # debug_show(Blob.toArray(compressed_even)));
//         assert compressed_even == hexToBlob(expected_even);

//         let public_key_odd : [Nat8] = [
//             0xE3, 0x10, 0x0D, 0x85, 0xEF, 0xAE, 0x93, 0xE0, 0xC2, 0xFC, 0x65, 0x4B, 0x2F, 0x0C, 0x33, 0x58,
//             0x4F, 0x21, 0x3A, 0x3F, 0xDF, 0xFD, 0x02, 0x3C, 0x82, 0x12, 0x77, 0xB2, 0x17, 0x89, 0xE0, 0x64,
//             0xE0, 0x6B, 0x45, 0x4F, 0x5C, 0xBA, 0x0E, 0xFF, 0x1C, 0xE8, 0x01, 0xD3, 0x83, 0x5C, 0x39, 0xEC,
//             0x01, 0xCA, 0x94, 0x9C, 0xA8, 0x77, 0xC0, 0xB5, 0x5B, 0xBD, 0xEC, 0xA8, 0xFF, 0x84, 0x91, 0xD9
//         ];
//         let expected_odd : [Nat8] = Array.append([0x03 : Nat8], Array.subArray(public_key_odd, 0, 32));
//         let compressed_odd = Address.compress_public_key(hexToBlob(public_key_odd), ECDSA, 33);
//         Debug.print("ECDSA compressed odd key: " # debug_show(Blob.toArray(compressed_odd)));
//         assert compressed_odd == hexToBlob(expected_odd);
//     };

//     // Test for invalid compression
//     func test_invalid_compress_address() {
//         Debug.print("Testing invalid compression");
//         let public_key : [Nat8] = [
//             0xE3, 0x10, 0x0D, 0x85, 0xEF, 0xAE, 0x93, 0xE0, 0xC2, 0xFC, 0x65, 0x4B, 0x2F, 0x0C, 0x33, 0x58,
//             0x4F, 0x21, 0x3A, 0x3F, 0xDF, 0xFD, 0x02, 0x3C, 0x82, 0x12, 0x77, 0xB2, 0x17, 0x89, 0xE0, 0x64,
//             0xE0, 0x6B, 0x45, 0x4F, 0x5C, 0xBA, 0x0E, 0xFF, 0x1C, 0xE8, 0x01, 0xD3, 0x83, 0x5C, 0x39, 0xEC,
//             0x01, 0xCA, 0x94, 0x9C, 0xA8, 0x77, 0xC0, 0xB5, 0x5B, 0xBD, 0xEC, 0xA8, 0xFF, 0x84, 0x91, 0xD9
//         ];
//         let result_schnorr = Address.compress_public_key(hexToBlob(public_key), SCHNORR, 31); // Too small
//         Debug.print("Schnorr invalid compression: " # debug_show(Blob.toArray(result_schnorr)));
//         assert result_schnorr == Blob.fromArray([]);
//         let result_ecdsa = Address.compress_public_key(hexToBlob(public_key), ECDSA, 32); // Too small
//         Debug.print("ECDSA invalid compression: " # debug_show(Blob.toArray(result_ecdsa)));
//         assert result_ecdsa == Blob.fromArray([]);
//     };

//     // Test for ECDSA address from ICP ECDSA public key
//     func test_ecdsa_address_from_icp_public_key() : async () {
//         Debug.print("Starting ECDSA public key test");
//         let management_canister = actor("aaaaa-aa") : actor {
//             ecdsa_public_key : {
//                 canister_id : ?Principal;
//                 derivation_path : [Blob];
//                 key_id : { curve : { #secp256k1 }; name : Text }
//             } -> async { public_key : Blob; chain_code : Blob };
//         };
//         try {
//             Debug.print("Adding cycles for ecdsa_public_key call");
//             Cycles.add<system>(30_000_000_000);
//             let result = await management_canister.ecdsa_public_key({
//                 canister_id = null;
//                 derivation_path = [];
//                 key_id = { curve = #secp256k1; name = "dfx_test_key" };
//             });
//             let public_key_opt = to_uncompressed_public_key(result.public_key);
//             switch (public_key_opt) {
//                 case (null) {
//                     Debug.print("Failed to process public key: invalid format");
//                     assert false;
//                 };
//                 case (?public_key) {
//                     Debug.print("ICP ECDSA public key: " # debug_show(Blob.toArray(public_key)) # ", size: " # debug_show(public_key.size()));
//                     assert public_key.size() == 33 or public_key.size() == 65; // Accept compressed or uncompressed
//                     Debug.print("Calling address_from_pubkey with ECDSA type and length " # debug_show(ECDSA_ADDRESS_LEN));
//                     let address = Address.address_from_pubkey(public_key, ECDSA, ECDSA_ADDRESS_LEN);
//                     Debug.print("Derived Kaspa address: " # address # ", size: " # debug_show(address.size()));
//                     assert address.size() > 0;
//                     assert Text.startsWith(address, #text("kaspa:"));
//                 };
//             };
//         } catch (err) {
//             Debug.print("Failed to get ECDSA public key: " # Error.message(err));
//             assert false;
//         };
//     };

//     // Run all tests
//     Debug.print("Executing all tests");
//     test_schnorr_address_from_public_key();
//     test_p2sh_address_from_public_key();
//     test_ecdsa_address_from_public_key();
//     test_invalid_type();
//     test_compress_address_schnorr();
//     test_compress_address_ecdsa();
//     test_invalid_compress_address();
//     //await test_ecdsa_address_from_icp_public_key();
//   };
// };














// import Array "mo:base/Array";
// import Blob "mo:base/Blob";
// import Text "mo:base/Text";
// import Nat8 "mo:base/Nat8";
// import Debug "mo:base/Debug";
// import Iter "mo:base/Iter";
// import Result "mo:base/Result";
// import Buffer "mo:base/Buffer";
// import Int "mo:base/Int";
// import Char "mo:base/Char";
// import Nat32 "mo:base/Nat32";

// // Import the official MOPS ECDSA package
// import ECDSA "mo:ecdsa";

// // The Address module to be tested
// import Address "../src/kaspa/address";

// persistent actor {

// func hexCharToNat8(c : Char) : Nat8 {
//     let n : Nat32 = Char.toNat32(c);
//     if (n >= Char.toNat32('0') and n <= Char.toNat32('9')) {
//         Nat8.fromNat(Nat32.toNat(n - Char.toNat32('0')))
//     } else if (n >= Char.toNat32('a') and n <= Char.toNat32('f')) {
//         Nat8.fromNat(10 + Nat32.toNat(n - Char.toNat32('a')))
//     } else if (n >= Char.toNat32('A') and n <= Char.toNat32('F')) {
//         Nat8.fromNat(10 + Nat32.toNat(n - Char.toNat32('A')))
//     } else {
//         assert false; // invalid hex digit
//         0
//     }
// };


// func array_from_hex(hex : Text) : [Nat8] {
//     let chars = Text.toArray(hex);
//     let start = if (Text.startsWith(hex, #text("0x"))) { 2 } else { 0 };
//     let buffer = Buffer.Buffer<Nat8>((chars.size() - start) / 2);

//     var i = start;
//     while (i < chars.size()) {
//         let hi = hexCharToNat8(chars[i]);
//         let lo = hexCharToNat8(chars[i + 1]);
//         buffer.add(hi * 16 + lo);
//         i += 2;
//     };

//     Buffer.toArray(buffer)
// };

//   public func runTests() : async () {
//     Debug.print("\n--- Running Kaspa Address Tests ---\n");

// // Test 1: Schnorr address generation from a 32-byte public key
//     func test_schnorr_address() {
//         Debug.print("🧪 Testing Schnorr (P2PK) address generation...");
//         let pubkey_bytes = array_from_hex("21eb0c4270128b16c93c5f0dac48d56051a6237dae997b58912695052818e348");

//         let expected_address = "kaspa:qqs7krzzwqfgk9kf830smtzg64s9rf3r0khfj76cjynf2pfgrr35saatu88xq";
//         let actual_address = Address.address_from_pubkey(Blob.fromArray(pubkey_bytes), Address.SCHNORR);

//         Debug.print("   -> Generated Address: " # actual_address);
//         assert(Text.equal(actual_address, expected_address));
//         Debug.print("   ✅ Passed!");
//     };

//     // Test 2: P2SH address generation from a 32-byte hash
//     func test_p2sh_address() {
//         Debug.print("🧪 Testing P2SH address generation...");
//         let script_hash_bytes = array_from_hex("f38031f61ca23d70844f63a477d07f0b2c2decab907c2e096e548b0e08721c79");
        
//         let expected_address = "kaspa:precqv0krj3r6uyyfa36ga7s0u9jct0v4wg8ctsfde2gkrsgwgw8jgxfzfc98";
//         let actual_address = Address.address_from_pubkey(Blob.fromArray(script_hash_bytes), Address.P2SH);
        
//         Debug.print("   -> Generated Address: " # actual_address);
//         assert(Text.equal(actual_address, expected_address));
//         Debug.print("   ✅ Passed!");
//     };

//     // Test 3: ECDSA address generation using the `mo:ecdsa` package
//     func test_ecdsa_address_with_package() {
//         Debug.print("🧪 Testing ECDSA (P2PK) address generation with mo:ecdsa package...");

//         // 1. Define a known private key (secret)
//         //let secret_bytes = array_from_hex("a0dc65ffca799873cbea0ac274015b9526505daaaed3a195c8108bea6f669424");
//         let secret_bytes = array_from_hex("53a1329d81bcc45ce5997b09e13d023820168b80403e9c237e0c825a6dec44d7");

//         // 2. Import the private key using the ECDSA library
//         let curve = ECDSA.secp256k1Curve();
//         let privateKeyResult = ECDSA.privateKeyFromBytes(secret_bytes.vals(), #raw({ curve = curve }));

//         switch (privateKeyResult) {
//             case (#err(e)) {
//                 Debug.print("   🚨 Test failed: Could not import private key: " # e);
//                 assert false; // Force failure
//             };
//             case (#ok(privateKey)) {
//                 // 3. Get the corresponding public key
//                 let publicKey = privateKey.getPublicKey();

//                 // 4. Export the public key to the 33-byte compressed format
//                 let compressed_pubkey_bytes = publicKey.toBytes(#compressed);
//                 let compressed_pubkey_blob = Blob.fromArray(compressed_pubkey_bytes);
                
//                 // Optional: Verify the derived public key is what we expect
//                 //let expected_pubkey_hex = "03d5fdc7ad11a65d0bbe7882fc3dbc91b5861d182dcce79f7c1be5bfd30a677cd6";
//                 // let expected_pubkey_hex = "03fb0609c4ecf3f38163dcb11830e4341195d3ee82784ec382642e7b935f0d0732";
//                 // assert(compressed_pubkey_blob == Blob.fromArray(array_from_hex(expected_pubkey_hex)));

//                 // 5. Generate the Kaspa address from the compressed public key blob
//                 //let expected_address = "kaspa:qypdtlw845g6vhgtheug9lpahjgmtpsarqkueeul0sd7t07npfnhe4s7fd82n0v";
//                 let expected_address = "kaspa:qplgvm9gcedp9djda9q590j5zdt8jwj7tyyy7nw38wpj0pun7muj6jut47fan";
//                 let actual_address = Address.address_from_pubkey(compressed_pubkey_blob, Address.ECDSA);

//                 Debug.print("   -> Generated Address: " # actual_address);
//                 Debug.print("   -> Expected Address: " # expected_address);
//                 assert(Text.equal(actual_address, expected_address));
//                 Debug.print("   ✅ Passed!");
//             };
//         };
//     };

//     // Test 4: Invalid public key length
//     func test_invalid_length() {
//         Debug.print("🧪 Testing address generation with invalid key lengths...");
//         let short_key = Blob.fromArray(array_from_hex("010203"));
        
//         let schnorr_res = Address.address_from_pubkey(short_key, Address.SCHNORR);
//         assert(schnorr_res == "");

//         let ecdsa_res = Address.address_from_pubkey(short_key, Address.ECDSA);
//         assert(ecdsa_res == "");
//         Debug.print("   ✅ Passed!");
//     };

//     // --- Execute All Tests ---
//     test_schnorr_address();
//     test_p2sh_address();
//     test_ecdsa_address_with_package();
//     test_invalid_length();
    
//     Debug.print("\n--- All tests completed successfully! ---\n");
//   };
// };


























// import Array "mo:base/Array";
// import Blob "mo:base/Blob";
// import Text "mo:base/Text";
// import Nat8 "mo:base/Nat8";
// import Debug "mo:base/Debug";
// import Iter "mo:base/Iter";
// import Result "mo:base/Result";
// import Buffer "mo:base/Buffer";
// import Int "mo:base/Int";
// import Char "mo:base/Char";
// import Nat32 "mo:base/Nat32";
// import Nat "mo:base/Nat";

// // Import the official MOPS ECDSA package
// import ECDSA "mo:ecdsa";

// // The Address module to be tested
// import Address "../src/kaspa/address";

// persistent actor {

// func hexCharToNat8(c : Char) : Nat8 {
//     let n : Nat32 = Char.toNat32(c);
//     if (n >= Char.toNat32('0') and n <= Char.toNat32('9')) {
//         Nat8.fromNat(Nat32.toNat(n - Char.toNat32('0')))
//     } else if (n >= Char.toNat32('a') and n <= Char.toNat32('f')) {
//         Nat8.fromNat(10 + Nat32.toNat(n - Char.toNat32('a')))
//     } else if (n >= Char.toNat32('A') and n <= Char.toNat32('F')) {
//         Nat8.fromNat(10 + Nat32.toNat(n - Char.toNat32('A')))
//     } else {
//         assert false; // invalid hex digit
//         0
//     }
// };

// func array_from_hex(hex : Text) : [Nat8] {
//     let chars = Text.toArray(hex);
//     let start = if (Text.startsWith(hex, #text("0x"))) { 2 } else { 0 };
//     let buffer = Buffer.Buffer<Nat8>((chars.size() - start) / 2);

//     var i = start;
//     while (i < chars.size()) {
//         let hi = hexCharToNat8(chars[i]);
//         let lo = hexCharToNat8(chars[i + 1]);
//         buffer.add(hi * 16 + lo);
//         i += 2;
//     };

//     Buffer.toArray(buffer)
// };

// // Helper function to convert array to hex string for debugging
// func hex_from_array(bytes: [Nat8]) : Text {
//     let hexChars = ['0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f'];
//     var result = "";
//     for (byte in bytes.vals()) {
//         let high = Nat8.toNat(byte / 16);
//         let low = Nat8.toNat(byte % 16);
//         result := result # Text.fromChar(hexChars[high]) # Text.fromChar(hexChars[low]);
//     };
//     result
// };

// func debug_array(arr: [Nat8]) : Text {
//     var result = "[";
//     for (i in arr.keys()) {
//         if (i > 0) result := result # ", ";
//         result := result # "0x" # (if (arr[i] < 16) "0" else "") # hex_from_array([arr[i]]);
//     };
//     result # "]"
// };

//   public func runTests() : async () {
//     Debug.print("\n--- Running Kaspa Address Tests ---\n");

// // Test 1: Schnorr address generation from a 32-byte public key
//     func test_schnorr_address() {
//         Debug.print("🧪 Testing Schnorr (P2PK) address generation...");
//         let pubkey_bytes = array_from_hex("21eb0c4270128b16c93c5f0dac48d56051a6237dae997b58912695052818e348");

//         let expected_address = "kaspa:qqs7krzzwqfgk9kf830smtzg64s9rf3r0khfj76cjynf2pfgrr35saatu88xq";
//         let actual_address = Address.address_from_pubkey(Blob.fromArray(pubkey_bytes), Address.SCHNORR);

//         Debug.print("   -> Generated Address: " # actual_address);
//         assert(Text.equal(actual_address, expected_address));
//         Debug.print("   ✅ Passed!");
//     };

//     // Test 2: P2SH address generation from a 32-byte hash
//     func test_p2sh_address() {
//         Debug.print("🧪 Testing P2SH address generation...");
//         let script_hash_bytes = array_from_hex("f38031f61ca23d70844f63a477d07f0b2c2decab907c2e096e548b0e08721c79");
        
//         let expected_address = "kaspa:precqv0krj3r6uyyfa36ga7s0u9jct0v4wg8ctsfde2gkrsgwgw8jgxfzfc98";
//         let actual_address = Address.address_from_pubkey(Blob.fromArray(script_hash_bytes), Address.P2SH);
        
//         Debug.print("   -> Generated Address: " # actual_address);
//         assert(Text.equal(actual_address, expected_address));
//         Debug.print("   ✅ Passed!");
//     };

//     // DEBUG VERSION: ECDSA address generation with detailed debugging
//     func test_ecdsa_address_with_package_debug() {
//         Debug.print("🧪 Testing ECDSA (P2PK) address generation with mo:ecdsa package (DEBUG)...");

//         // Known working data from kaspad CLI
//         let private_key_hex = "53a1329d81bcc45ce5997b09e13d023820168b80403e9c237e0c825a6dec44d7";
//         let expected_address = "kaspa:qplgvm9gcedp9djda9q590j5zdt8jwj7tyyy7nw38wpj0pun7muj6jut47fan";
        
//         Debug.print("   Private key: " # private_key_hex);
//         Debug.print("   Expected address: " # expected_address);

//         let secret_bytes = array_from_hex(private_key_hex);
//         Debug.print("   Private key bytes length: " # Nat.toText(secret_bytes.size()));

//         let curve = ECDSA.secp256k1Curve();
//         let privateKeyResult = ECDSA.privateKeyFromBytes(secret_bytes.vals(), #raw({ curve = curve }));

//         switch (privateKeyResult) {
//             case (#err(e)) {
//                 Debug.print("   🚨 Test failed: Could not import private key: " # e);
//                 assert false;
//             };
//             case (#ok(privateKey)) {
//                 Debug.print("   ✅ Successfully imported private key");
                
//                 let publicKey = privateKey.getPublicKey();
//                 let compressed_pubkey_bytes = publicKey.toBytes(#compressed);
                
//                 Debug.print("   Compressed public key length: " # Nat.toText(compressed_pubkey_bytes.size()));
//                 Debug.print("   Expected length for ECDSA: " # Nat.toText(Address.ECDSA_PAYLOAD_LEN));
//                 Debug.print("   Compressed public key (hex): " # hex_from_array(compressed_pubkey_bytes));
                
//                 // Check compression format
//                 if (compressed_pubkey_bytes.size() > 0) {
//                     let first_byte = compressed_pubkey_bytes[0];
//                     Debug.print("   First byte (compression flag): 0x" # hex_from_array([first_byte]));
//                     if (first_byte != 0x02 and first_byte != 0x03) {
//                         Debug.print("   ⚠️  Warning: First byte should be 0x02 or 0x03 for compressed key");
//                     };
//                 };
                
//                 let compressed_pubkey_blob = Blob.fromArray(compressed_pubkey_bytes);
//                 let actual_address = Address.address_from_pubkey(compressed_pubkey_blob, Address.ECDSA);
                
//                 Debug.print("   -> Generated Address: " # actual_address);
//                 Debug.print("   -> Expected Address: " # expected_address);
//                 Debug.print("   -> Addresses match: " # (if (Text.equal(actual_address, expected_address)) "✅ YES" else "❌ NO"));
                
//                 if (not Text.equal(actual_address, expected_address)) {
//                     Debug.print("   🔧 === MISMATCH DETECTED - INVESTIGATING ===");
                    
//                     // Let's compare with what kaspad expects
//                     // First, let's verify what public key kaspad would generate
//                     Debug.print("   🔍 Generated public key: " # hex_from_array(compressed_pubkey_bytes));
//                     Debug.print("   📋 Length check: " # Nat.toText(compressed_pubkey_bytes.size()) # " bytes");
                    
//                     // Check if we can verify this public key externally
//                     // You can use this to verify: https://www.bitaddress.org or similar tool
//                     Debug.print("   💡 Verify this public key with external tools to confirm");
//                     Debug.print("   💡 Private key: " # private_key_hex);
//                     Debug.print("   💡 Public key: " # hex_from_array(compressed_pubkey_bytes));
//                 };
                
//                 // Comment out the assertion temporarily to see what happens
//                 // assert(Text.equal(actual_address, expected_address));
//                 Debug.print("   🔄 Test completed (assertion commented out for debugging)");
//             };
//         };
//     };

//     // Original test (commented out for now)
//     func test_ecdsa_address_with_package() {
//         Debug.print("🧪 Testing ECDSA (P2PK) address generation with mo:ecdsa package...");

//         let secret_bytes = array_from_hex("53a1329d81bcc45ce5997b09e13d023820168b80403e9c237e0c825a6dec44d7");
//         let curve = ECDSA.secp256k1Curve();
//         let privateKeyResult = ECDSA.privateKeyFromBytes(secret_bytes.vals(), #raw({ curve = curve }));

//         switch (privateKeyResult) {
//             case (#err(e)) {
//                 Debug.print("   🚨 Test failed: Could not import private key: " # e);
//                 assert false;
//             };
//             case (#ok(privateKey)) {
//                 let publicKey = privateKey.getPublicKey();
//                 let compressed_pubkey_bytes = publicKey.toBytes(#compressed);
//                 let compressed_pubkey_blob = Blob.fromArray(compressed_pubkey_bytes);
                
//                 let expected_address = "kaspa:qplgvm9gcedp9djda9q590j5zdt8jwj7tyyy7nw38wpj0pun7muj6jut47fan";
//                 let actual_address = Address.address_from_pubkey(compressed_pubkey_blob, Address.ECDSA);

//                 Debug.print("   -> Generated Address: " # actual_address);
//                 Debug.print("   -> Expected Address: " # expected_address);
//                 assert(Text.equal(actual_address, expected_address));
//                 Debug.print("   ✅ Passed!");
//             };
//         };
//     };
    

//     // Test 4: Invalid public key length
//     func test_invalid_length() {
//         Debug.print("🧪 Testing address generation with invalid key lengths...");
//         let short_key = Blob.fromArray(array_from_hex("010203"));
        
//         let schnorr_res = Address.address_from_pubkey(short_key, Address.SCHNORR);
//         assert(schnorr_res == "");

//         let ecdsa_res = Address.address_from_pubkey(short_key, Address.ECDSA);
//         assert(ecdsa_res == "");
//         Debug.print("   ✅ Passed!");
//     };

//     // --- Execute All Tests ---
//     test_schnorr_address();
//     test_p2sh_address();
//     test_ecdsa_address_with_package();
//     //test_ecdsa_address_with_package_debug();  // Use debug version
//     test_invalid_length();
    
//     Debug.print("\n--- All tests completed! ---\n");
//   };
// };








import Debug "mo:base/Debug";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Blob "mo:base/Blob";
import Address "../src/kaspa/address";

persistent actor {
    // Simple assertion function with custom toText rendering
    private func assertEqual<T>(actual : T, expected : T, message : Text, eq : (T, T) -> Bool, toText : T -> Text) : Bool {
        if (eq(actual, expected)) {
            Debug.print("✅ PASS: " # message);
            true
        } else {
            Debug.print("❌ FAIL: " # message # " (expected: " # toText(expected) # ", actual: " # toText(actual) # ")");
            false
        }
    };

    // Text rendering for Text
    private func textToText(t : Text) : Text {
        t
    };

    // Text rendering for [Nat8]
    private func bytesToText(bytes : [Nat8]) : Text {
        Address.hex_from_array(bytes)
    };

    // Text rendering for ?(Nat, [Nat8])
    private func optTupleToText(opt : ?(Nat, [Nat8])) : Text {
        switch (opt) {
            case (null) "null";
            case (?(addr_type, pubkey)) {
                "(addr_type: " # Nat.toText(addr_type) # ", pubkey: " # Address.hex_from_array(pubkey) # ")"
            };
        }
    };

    // Equality function for Text
    private func textEq(a : Text, b : Text) : Bool {
        Text.equal(a, b)
    };

    // Equality function for [Nat8]
    private func bytesEq(a : [Nat8], b : [Nat8]) : Bool {
        Array.equal(a, b, func(x : Nat8, y : Nat8) : Bool { x == y })
    };

    // Equality function for ?(Nat, [Nat8])
    private func optTupleEq(a : ?(Nat, [Nat8]), b : ?(Nat, [Nat8])) : Bool {
        switch (a, b) {
            case (null, null) true;
            case (?(a_type, a_pubkey), ?(b_type, b_pubkey)) {
                a_type == b_type and bytesEq(a_pubkey, b_pubkey)
            };
            case _ false;
        }
    };

    public func runTests() : async Text {
        var passed : Nat = 0;
        var total : Nat = 0;

        // Test 1: hex_from_array
        let test_bytes = Address.array_from_hex("abcd");
        total += 1;
        if (assertEqual(Address.hex_from_array(test_bytes), "abcd", "hex_from_array: [0xAB, 0xCD]", textEq, textToText)) {
            passed += 1;
        };

        total += 1;
        if (assertEqual(Address.hex_from_array([]), "", "hex_from_array: empty array", textEq, textToText)) {
            passed += 1;
        };

        total += 1;
        if (assertEqual(Address.hex_from_array([0xFF]), "ff", "hex_from_array: single byte [0xFF]", textEq, textToText)) {
            passed += 1;
        };

        // Test 2: pubkey_to_script (SCHNORR)
        let schnorr_pubkey = Address.array_from_hex("21eb0c4270128b16c93c5f0dac48d56051a6237dae997b58912695052818e348");
        let expected_schnorr_script = "20" # "21eb0c4270128b16c93c5f0dac48d56051a6237dae997b58912695052818e348" # "ac";
        total += 1;
        if (assertEqual(Address.pubkey_to_script(schnorr_pubkey, Address.SCHNORR), expected_schnorr_script, "pubkey_to_script: SCHNORR valid", textEq, textToText)) {
            passed += 1;
        };

        // Test 3: pubkey_to_script (ECDSA)
        let ecdsa_pubkey = Address.array_from_hex("0294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37"); // 33-byte pubkey
        let expected_ecdsa_script = "21" # "0294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37" # "ab";
        total += 1;
        if (assertEqual(Address.pubkey_to_script(ecdsa_pubkey, Address.ECDSA), expected_ecdsa_script, "pubkey_to_script: ECDSA valid (33-byte pubkey)", textEq, textToText)) {
            passed += 1;
        };

        // Test 4: pubkey_to_script (invalid addr_type)
        total += 1;
        if (assertEqual(Address.pubkey_to_script(schnorr_pubkey, Address.P2SH), "", "pubkey_to_script: invalid addr_type (P2SH)", textEq, textToText)) {
            passed += 1;
        };

        // Test 5: pubkey_to_script (invalid SCHNORR length)
        let invalid_schnorr_pubkey = Address.array_from_hex("21eb0c4270128b16c93c5f0dac48d56051a6237dae997b58912695052818"); // 31 bytes
        total += 1;
        if (assertEqual(Address.pubkey_to_script(invalid_schnorr_pubkey, Address.SCHNORR), "", "pubkey_to_script: invalid SCHNORR pubkey length", textEq, textToText)) {
            passed += 1;
        };

        // Test 6: pubkey_to_script (invalid ECDSA length)
        let invalid_ecdsa_pubkey = Address.array_from_hex("0294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c"); // 32 bytes
        total += 1;
        if (assertEqual(Address.pubkey_to_script(invalid_ecdsa_pubkey, Address.ECDSA), "", "pubkey_to_script: invalid ECDSA pubkey length", textEq, textToText)) {
            passed += 1;
        };

        // Test 7: address_from_pubkey (SCHNORR)
        let schnorr_pubkey_blob = Blob.fromArray(schnorr_pubkey);
        let expected_schnorr_address = "kaspa:qqs7krzzwqfgk9kf830smtzg64s9rf3r0khfj76cjynf2pfgrr35saatu88xq";
        total += 1;
        if (assertEqual(Address.address_from_pubkey(schnorr_pubkey_blob, Address.SCHNORR), expected_schnorr_address, "address_from_pubkey: SCHNORR valid", textEq, textToText)) {
            passed += 1;
        };

        // Test 8: address_from_pubkey (P2SH)
        let p2sh_hash = Address.array_from_hex("f38031f61ca23d70844f63a477d07f0b2c2decab907c2e096e548b0e08721c79");
        let expected_p2sh_address = "kaspa:precqv0krj3r6uyyfa36ga7s0u9jct0v4wg8ctsfde2gkrsgwgw8jgxfzfc98";
        total += 1;
        if (assertEqual(Address.address_from_pubkey(Blob.fromArray(p2sh_hash), Address.P2SH), expected_p2sh_address, "address_from_pubkey: P2SH valid", textEq, textToText)) {
            passed += 1;
        };

        // Test 9: address_from_pubkey (ECDSA)
        let ecdsa_pubkey_blob = Blob.fromArray(ecdsa_pubkey);
        let expected_ecdsa_address = "kaspa:qypff6urmgk8452vjx55r63dhc38s6ewlavknmnefzgac42n3lt8cdchp86su6n";
        total += 1;
        if (assertEqual(Address.address_from_pubkey(ecdsa_pubkey_blob, Address.ECDSA), expected_ecdsa_address, "address_from_pubkey: ECDSA valid", textEq, textToText)) {
            passed += 1;
        };

        // Test 10: address_from_pubkey (invalid length)
        let short_key = Address.array_from_hex("010203");
        total += 1;
        if (assertEqual(Address.address_from_pubkey(Blob.fromArray(short_key), Address.SCHNORR), "", "address_from_pubkey: invalid SCHNORR length", textEq, textToText)) {
            passed += 1;
        };

        total += 1;
        if (assertEqual(Address.address_from_pubkey(Blob.fromArray(short_key), Address.ECDSA), "", "address_from_pubkey: invalid ECDSA length", textEq, textToText)) {
            passed += 1;
        };

        // Test 11: decode_address (SCHNORR)
        let schnorr_address = "kaspa:qqs7krzzwqfgk9kf830smtzg64s9rf3r0khfj76cjynf2pfgrr35saatu88xq";
        let expected_schnorr_tuple = ?(Address.SCHNORR, schnorr_pubkey);
        total += 1;
        if (assertEqual(Address.decode_address(schnorr_address), expected_schnorr_tuple, "decode_address: SCHNORR valid", optTupleEq, optTupleToText)) {
            passed += 1;
        };

        // Test 12: decode_address (invalid address)
        let invalid_address = "kaspa:invalid";
        total += 1;
        if (assertEqual(Address.decode_address(invalid_address), null, "decode_address: invalid address", optTupleEq, optTupleToText)) {
            passed += 1;
        };

        // Test 13: decode_address (ECDSA)
        let ecdsa_address = "kaspa:qypff6urmgk8452vjx55r63dhc38s6ewlavknmnefzgac42n3lt8cdchp86su6n";
        let expected_ecdsa_tuple = ?(Address.ECDSA, ecdsa_pubkey);
        total += 1;
        if (assertEqual(Address.decode_address(ecdsa_address), expected_ecdsa_tuple, "decode_address: ECDSA valid", optTupleEq, optTupleToText)) {
            passed += 1;
        };

        // Summary
        let summary = "Test Summary: " # Nat.toText(passed) # "/" # Nat.toText(total) # " tests passed";
        Debug.print(summary);
        summary
    };
};