// import Array "mo:base/Array";
// import Blob "mo:base/Blob";
// import Text "mo:base/Text";
// import Nat8 "mo:base/Nat8";

// import Address "../src/kaspa/address";
// import PersonalMessage "../src/kaspa/personal_message";

// // Helper: hex array to Blob
// func hexToBlob(hex : [Nat8]) : Blob {
//   Blob.fromArray(hex);
// };

// func test_ecdsa_personal_message_hello_kaspa() {
//   // Test message: "Hello Kaspa!" (same as Python tests)
//   let message = "Hello Kaspa!";
//   let message_blob : Blob = Text.encodeUtf8(message);
//   let message_bytes : [Nat8] = Blob.toArray(message_blob);
//   let out_hash = Array.init<Nat8>(32, 0);

//   // Hash the message
//   let hash_result = PersonalMessage.hash_personal_message(message_bytes, message_bytes.size(), out_hash);
//   assert hash_result;

//   // Expected hash from Ledger test (should match message_data.to_hash())
//   let expected_hash : [Nat8] = [
//     0x2E, 0x55, 0xDE, 0xDA, 0x4A, 0x52, 0x24, 0x20,
//     0x8D, 0xBD, 0x4D, 0x93, 0xCF, 0xE5, 0xAA, 0x22,
//     0xD9, 0x45, 0xEA, 0xA6, 0x31, 0x72, 0xE3, 0x29,
//     0xC4, 0x9A, 0xFE, 0xD6, 0x2F, 0x0E, 0x15, 0x10
//   ];
//   assert Array.freeze(out_hash) == expected_hash;

//   // Test public key (64 bytes, no 0x04 prefix)
//   let public_key = Blob.fromArray([
//     0xD5, 0xFD, 0xC7, 0xAD, 0x11, 0xA6, 0x5D, 0x0B, 0xBE, 0x78, 0x82, 0xFC, 0x3D, 0xBC, 0x91, 0xB5,
//     0x86, 0x1D, 0x18, 0x2D, 0xCC, 0xE7, 0x9F, 0x7C, 0x1B, 0xE5, 0xBF, 0xD3, 0x0A, 0x67, 0x7C, 0xD6,
//     0xC5, 0x62, 0xAD, 0x66, 0xAB, 0xCD, 0xB1, 0xEC, 0x02, 0xF3, 0xE4, 0xB0, 0x7C, 0x11, 0xBC, 0x5A,
//     0x94, 0xA6, 0x85, 0xFE, 0xDB, 0x5D, 0x55, 0x87, 0x07, 0x6E, 0x48, 0xB1, 0x2D, 0xA6, 0xC2, 0x82
//   ]);

//   // Derive Kaspa ECDSA address (address_type = 1, matches Python tests)
//   let expected_address = "kaspa:qypdtlw845g6vhgtheug9lpahjgmtpsarqkueeul0sd7t07npfnhe4s7fd82n0v";
//   let address = Address.address_from_pubkey(public_key, Address.ECDSA, Address.ECDSA_ADDRESS_LEN);
//   assert address == expected_address;

//   // Mock private key (same as ledger tests)
//   let private_key = Blob.fromArray([
//     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
//     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
//     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
//     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03
//   ]);

//   // Sign the hash
//   let hash_array = Array.freeze(out_hash);
//   let message_hash_blob = Blob.fromArray(hash_array);
  
//   switch (PersonalMessage.ecdsa_sign(message_hash_blob, private_key)) {
//     case (null) assert false;
//     case (?signature) {
//       // Expected signature from ledger tests
//       let expected_signature : [Nat8] = [
//         0x40, 0xB9, 0xBB, 0x2B, 0xE0, 0xAE, 0x02, 0x60, 0x72, 0x79, 0xED, 0xA6, 0x40, 0x15, 0xA8, 0xD8,
//         0x6E, 0x37, 0x63, 0x27, 0x91, 0x70, 0x34, 0x0B, 0x82, 0x43, 0xF7, 0xCE, 0x53, 0x44, 0xD7, 0x7A,
//         0xFF, 0x11, 0x91, 0x59, 0x8B, 0xAF, 0x2F, 0xD2, 0x61, 0x49, 0xCA, 0xC3, 0xB4, 0xB1, 0x2C, 0x2C,
//         0x43, 0x32, 0x61, 0xC0, 0x08, 0x34, 0xDB, 0x60, 0x98, 0xCB, 0x17, 0x2A, 0xA4, 0x8E, 0xF5, 0x22
//       ];
//       assert Blob.toArray(signature) == expected_signature;

//       // Verify signature (like check_signature_validity in Python tests)
//       let is_valid = PersonalMessage.ecdsa_verify(message_hash_blob, signature, public_key);
//       assert is_valid;
//     };
//   };
// };

// // Test with Japanese text (like the Python test_sign_message_kanji)
// func test_ecdsa_personal_message_kanji() {
//   let message = "こんにちは世界"; // "Hello World" in Japanese
//   let message_blob : Blob = Text.encodeUtf8(message);
//   let message_bytes : [Nat8] = Blob.toArray(message_blob);
//   let out_hash = Array.init<Nat8>(32, 0);

//   // Hash the message
//   let hash_result = PersonalMessage.hash_personal_message(message_bytes, message_bytes.size(), out_hash);
//   assert hash_result;

//   // The hash will be different for Japanese text
//   // In a real implementation, you'd get the expected hash from the ledger
// };

// // Test message length validation (like test_sign_message_too_long)
// func test_message_too_long() {
//   let long_message = "Lorem ipsum dolor sit amet. Aut omnis amet id voluptatem eligendi sit accusantium dolorem 33 corrupti necessitatibus hic consequatur quod et maiores alias non molestias suscipit? Est voluptatem magni qui odit eius est eveniet cupiditate id eius";
//   let message_blob : Blob = Text.encodeUtf8(long_message);
//   let message_bytes : [Nat8] = Blob.toArray(message_blob);
//   let out_hash = Array.init<Nat8>(32, 0);

//   // This should potentially fail or handle the long message appropriately
//   let hash_result = PersonalMessage.hash_personal_message(message_bytes, message_bytes.size(), out_hash);
//   // Add appropriate length validation logic here
// };

// // Run all tests
// func run_tests() {
//   test_ecdsa_personal_message_hello_kaspa();
//   test_ecdsa_personal_message_kanji();
//   test_message_too_long();
// };

// run_tests();






// import Array "mo:base/Array";
// import Blob "mo:base/Blob";
// import Text "mo:base/Text";
// import Nat8 "mo:base/Nat8";
// import Debug "mo:base/Debug";
// import Principal "mo:base/Principal";

// import Address "../src/kaspa/address";
// import PersonalMessage "../src/kaspa/personal_message";


// persistent actor {

// // Helper: hex array to Blob
// func hexToBlob(hex : [Nat8]) : Blob {
//   Blob.fromArray(hex);
// };

//   public func runTests() : async () {
//     Debug.print("Running personal message tests");

//     // Test message: "Hello Kaspa!" (same as Python tests)
//     let message = "Hello Kaspa!";
//     let message_blob : Blob = Text.encodeUtf8(message);
//     let message_bytes : [Nat8] = Blob.toArray(message_blob);
//     let out_hash = Array.init<Nat8>(32, 0);

//     // Hash the message
//     let hash_result = PersonalMessage.hash_personal_message(message_bytes, message_bytes.size(), out_hash);
//     assert hash_result;

//     // Expected hash from Ledger test
//     let expected_hash : [Nat8] = [
//       0x2E, 0x55, 0xDE, 0xDA, 0x4A, 0x52, 0x24, 0x20,
//       0x8D, 0xBD, 0x4D, 0x93, 0xCF, 0xE5, 0xAA, 0x22,
//       0xD9, 0x45, 0xEA, 0xA6, 0x31, 0x72, 0xE3, 0x29,
//       0xC4, 0x9A, 0xFE, 0xD6, 0x2F, 0x0E, 0x15, 0x10
//     ];
//     assert Array.freeze(out_hash) == expected_hash;

//     // Test public key (64 bytes, no 0x04 prefix)
//     let public_key = Blob.fromArray([
//       0xD5, 0xFD, 0xC7, 0xAD, 0x11, 0xA6, 0x5D, 0x0B, 0xBE, 0x78, 0x82, 0xFC, 0x3D, 0xBC, 0x91, 0xB5,
//       0x86, 0x1D, 0x18, 0x2D, 0xCC, 0xE7, 0x9F, 0x7C, 0x1B, 0xE5, 0xBF, 0xD3, 0x0A, 0x67, 0x7C, 0xD6,
//       0xC5, 0x62, 0xAD, 0x66, 0xAB, 0xCD, 0xB1, 0xEC, 0x02, 0xF3, 0xE4, 0xB0, 0x7C, 0x11, 0xBC, 0x5A,
//       0x94, 0xA6, 0x85, 0xFE, 0xDB, 0x5D, 0x55, 0x87, 0x07, 0x6E, 0x48, 0xB1, 0x2D, 0xA6, 0xC2, 0x82
//     ]);

//     // Derive Kaspa ECDSA address
//     let expected_address = "kaspa:qypdtlw845g6vhgtheug9lpahjgmtpsarqkueeul0sd7t07npfnhe4s7fd82n0v";
//     let address = Address.address_from_pubkey(public_key, Address.ECDSA, Address.ECDSA_ADDRESS_LEN);
//     assert address == expected_address;

//     // Sign the message
//     // let derivation_path : [Blob] = []; // Empty for testing
//     // let key_name = "dfx_test_key";
//     // let sign_result = await PersonalMessage.sign_personal_message(message, derivation_path, key_name);
//     // switch (sign_result) {
//     //   case (null) {
//     //     Debug.print("sign_personal_message returned null");
//     //     assert false;
//     //   };
//     //   case (?signature) {
//     //     // Check signature length
//     //     assert signature.size() == 64;
//     //     Debug.print("Signature: " # debug_show(Blob.toArray(signature)));

//     //     // Expected signature from ledger tests (optional, for mainnet testing)
//     //     let expected_signature : [Nat8] = [
//     //       0x40, 0xB9, 0xBB, 0x2B, 0xE0, 0xAE, 0x02, 0x60, 0x72, 0x79, 0xED, 0xA6, 0x40, 0x15, 0xA8, 0xD8,
//     //       0x6E, 0x37, 0x63, 0x27, 0x91, 0x70, 0x34, 0x0B, 0x82, 0x43, 0xF7, 0xCE, 0x53, 0x44, 0xD7, 0x7A,
//     //       0xFF, 0x11, 0x91, 0x59, 0x8B, 0xAF, 0x2F, 0xD2, 0x61, 0x49, 0xCA, 0xC3, 0xB4, 0xB1, 0x2C, 0x2C,
//     //       0x43, 0x32, 0x61, 0xC0, 0x08, 0x34, 0xDB, 0x60, 0x98, 0xCB, 0x17, 0x2A, 0xA4, 0x8E, 0xF5, 0x22
//     //     ];
//     //     // Comment out for local testing due to signature variability
//     //     // assert Blob.toArray(signature) == expected_signature;

//     //     // Verify signature
//     //     let hash_array = Array.freeze(out_hash);
//     //     let message_hash_blob = Blob.fromArray(hash_array);
//     //     let is_valid = PersonalMessage.ecdsa_verify(message_hash_blob, signature, public_key);
//     //     assert is_valid; // Mock verification for now
//     //   };
//     // };

//     // Test Japanese message
//     let kanji_message = "こんにちは世界"; // "Hello World" in Japanese
//     let kanji_message_blob : Blob = Text.encodeUtf8(kanji_message);
//     let kanji_message_bytes : [Nat8] = Blob.toArray(kanji_message_blob);
//     let kanji_out_hash = Array.init<Nat8>(32, 0);

//     let kanji_hash_result = PersonalMessage.hash_personal_message(kanji_message_bytes, kanji_message_bytes.size(), kanji_out_hash);
//     assert kanji_hash_result;

//     // Test long message
//     let long_message = "Lorem ipsum dolor sit amet. Aut omnis amet id voluptatem eligendi sit accusantium dolorem 33 corrupti necessitatibus hic consequatur quod et maiores alias non molestias suscipit? Est voluptatem magni qui odit eius est eveniet cupiditate id eius";
//     let long_message_blob : Blob = Text.encodeUtf8(long_message);
//     let long_message_bytes : [Nat8] = Blob.toArray(long_message_blob);
//     let long_out_hash = Array.init<Nat8>(32, 0);

//     let long_hash_result = PersonalMessage.hash_personal_message(long_message_bytes, long_message_bytes.size(), long_out_hash);
//     assert long_hash_result;
//   };
// };









import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Nat8 "mo:base/Nat8";
import Debug "mo:base/Debug";

import { test } "mo:test/async";

import Address "../src/kaspa/address";
import PersonalMessage "../src/kaspa/personal_message";

persistent actor {
  public func runTests() : async () {
    Debug.print("Running personal message and address tests");

    await test("hash personal message", func() : async () {
      let message = "Hello Kaspa!";
      let message_blob : Blob = Text.encodeUtf8(message);
      let message_bytes : [Nat8] = Blob.toArray(message_blob);
      let out_hash = Array.init<Nat8>(32, 0);

      let ok = PersonalMessage.hash_personal_message(message_bytes, message_bytes.size(), out_hash);
      assert ok;

      let expected_hash : [Nat8] = [
        0x2E, 0x55, 0xDE, 0xDA, 0x4A, 0x52, 0x24, 0x20,
        0x8D, 0xBD, 0x4D, 0x93, 0xCF, 0xE5, 0xAA, 0x22,
        0xD9, 0x45, 0xEA, 0xA6, 0x31, 0x72, 0xE3, 0x29,
        0xC4, 0x9A, 0xFE, 0xD6, 0x2F, 0x0E, 0x15, 0x10
      ];
      assert Array.freeze(out_hash) == expected_hash;
    });

    await test("ECDSA address", func() : async () {
      let compressed_public_key = Blob.fromArray([
        0x02,
        0xD5, 0xFD, 0xC7, 0xAD, 0x11, 0xA6, 0x5D, 0x0B, 0xBE, 0x78, 0x82, 0xFC,
        0x3D, 0xBC, 0x91, 0xB5, 0x86, 0x1D, 0x18, 0x2D, 0xCC, 0xE7, 0x9F, 0x7C,
        0x1B, 0xE5, 0xBF, 0xD3, 0x0A, 0x67, 0x7C, 0xD6
      ]);

      let expected_address = "kaspa:qypdtlw845g6vhgtheug9lpahjgmtpsarqkueeul0sd7t07npfnhe4s7fd82n0v";
      let address = Address.address_from_pubkey(compressed_public_key, Address.ECDSA);

      assert address != "";
      assert address == expected_address;
    });

    await test("Schnorr address", func() : async () {
      let schnorr_key = Blob.fromArray([
        0xD5, 0xFD, 0xC7, 0xAD, 0x11, 0xA6, 0x5D, 0x0B, 0xBE, 0x78, 0x82, 0xFC,
        0x3D, 0xBC, 0x91, 0xB5, 0x86, 0x1D, 0x18, 0x2D, 0xCC, 0xE7, 0x9F, 0x7C,
        0x1B, 0xE5, 0xBF, 0xD3, 0x0A, 0x67, 0x7C, 0xD6
      ]);

      let schnorr_address = Address.address_from_pubkey(schnorr_key, Address.SCHNORR);
      assert schnorr_address != "";
    });

    await test("P2SH address", func() : async () {
      let p2sh_hash = Blob.fromArray(Array.freeze(Array.init<Nat8>(32, 0)));
      let p2sh_address = Address.address_from_pubkey(p2sh_hash, Address.P2SH);
      assert p2sh_address != "";
    });

    await test("Japanese message", func() : async () {
      let kanji_message = "こんにちは世界";
      let kanji_message_blob = Text.encodeUtf8(kanji_message);
      let kanji_message_bytes = Blob.toArray(kanji_message_blob);
      let kanji_out_hash = Array.init<Nat8>(32, 0);

      let ok = PersonalMessage.hash_personal_message(kanji_message_bytes, kanji_message_bytes.size(), kanji_out_hash);
      assert ok;
    });

    await test("Long message", func() : async () {
      let long_message = "Lorem ipsum dolor sit amet ... cupiditate id eius";
      let long_message_blob = Text.encodeUtf8(long_message);
      let long_message_bytes = Blob.toArray(long_message_blob);
      let long_out_hash = Array.init<Nat8>(32, 0);

      let ok = PersonalMessage.hash_personal_message(long_message_bytes, long_message_bytes.size(), long_out_hash);
      assert ok;
    });
  };
};
