import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Char "mo:base/Char";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";


import Sighash "../src/kaspa/sighash";
import Types "../src/kaspa/types";

persistent actor {
  // Helper: Convert hex character to Nat8
  func hexCharToNat8(c: Char): Nat8 {
    let n: Nat32 = Char.toNat32(c);
    if (n >= Char.toNat32('0') and n <= Char.toNat32('9')) {
      Nat8.fromNat(Nat32.toNat(n - Char.toNat32('0')))
    } else if (n >= Char.toNat32('a') and n <= Char.toNat32('f')) {
      Nat8.fromNat(10 + Nat32.toNat(n - Char.toNat32('a')))
    } else if (n >= Char.toNat32('A') and n <= Char.toNat32('F')) {
      Nat8.fromNat(10 + Nat32.toNat(n - Char.toNat32('A')))
    } else {
      assert false; // Invalid hex digit
      0
    }
  };

  // Helper: Convert hex string to byte array
  func array_from_hex(hex: Text): [Nat8] {
    let chars = Text.toArray(hex);
    let start = if (Text.startsWith(hex, #text("0x"))) { 2 } else { 0 };
    let buffer = Buffer.Buffer<Nat8>((chars.size() - start) / 2);

    var i = start;
    while (i < chars.size()) {
      let hi = hexCharToNat8(chars[i]);
      let lo = hexCharToNat8(chars[i + 1]);
      buffer.add(hi * 16 + lo);
      i += 2;
    };

    Buffer.toArray(buffer)
  };

  // Helper: Convert byte array to hex string
  func hex_from_array(bytes: [Nat8]): Text {
    let hexChars = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'];
    var result = "";
    for (byte in bytes.vals()) {
      let high = Nat8.toNat(byte / 16);
      let low = Nat8.toNat(byte % 16);
      result := result # Text.fromChar(hexChars[high]) # Text.fromChar(hexChars[low]);
    };
    result
  };


  public func runTests(): async () {
    Debug.print("\n--- Running Kaspa Sighash Tests ---\n");

    // Test 1: is_standard_sighash_type
    func test_is_standard_sighash_type() {
      Debug.print("🧪 Testing is_standard_sighash_type...");
      let tests: [(Sighash.SigHashType, Text, Bool)] = [
        (Sighash.SigHashAll, "SigHashAll", true),
        (Sighash.SigHashNone, "SigHashNone", true),
        (Sighash.SigHashSingle, "SigHashSingle", true),
        (Sighash.SigHashAll_AnyOneCanPay, "SigHashAll_AnyOneCanPay", true),
        (Sighash.SigHashNone_AnyOneCanPay, "SigHashNone_AnyOneCanPay", true),
        (Sighash.SigHashSingle_AnyOneCanPay, "SigHashSingle_AnyOneCanPay", true),
        (0xFF: Nat8, "Invalid (0xFF)", false),
        (0x00: Nat8, "Invalid (0x00)", false),
        (0x08: Nat8, "Invalid (0x08)", false)
      ];

      for ((hashType, name, expected) in tests.vals()) {
        Debug.print("   -> Testing " # name # " (0x" # hex_from_array([hashType]) # ")");
        let result = Sighash.is_standard_sighash_type(hashType);
        Debug.print("      Result: " # (if result "true" else "false") # ", Expected: " # (if expected "true" else "false"));
        assert(result == expected);
      };
      Debug.print("   ✅ Passed!");
    };

    // Test 2: zero_hash
    func test_zero_hash() {
      Debug.print("🧪 Testing zero_hash...");
      let zero = Sighash.zero_hash();
      Debug.print("   -> Zero hash: " # hex_from_array(zero));
      Debug.print("   -> Length: " # Nat.toText(zero.size()));
      assert(zero.size() == 32);
      for (byte in zero.vals()) {
        assert(byte == 0);
      };
      Debug.print("   ✅ Passed!");
    };

    // Test 3: blake2b_256
    func test_blake2b_256() {
      Debug.print("🧪 Testing blake2b_256...");
      let input = array_from_hex("01020304");
      let key = ?"TransactionSigningHash";
      let hash = Sighash.blake2b_256(input, key);
      Debug.print("   -> Input: " # hex_from_array(input));
      Debug.print("   -> Key: " # (switch (key) { case (?k) k; case null "null" }));
      Debug.print("   -> Hash: " # hex_from_array(hash));
      Debug.print("   -> Length: " # Nat.toText(hash.size()));
      assert(hash.size() == 32);
      // Expected blake2b(digest_size=32, key=b"TransactionSigningHash").update(bytes.fromhex("01020304")).hexdigest()
      let expected_hash = array_from_hex("11dc0d4c4dfede32789eec374280104176a648b2756eedadc9f8d52134a81d19");
      assert(Array.equal(hash, expected_hash, Nat8.equal));
      Debug.print("   ✅ Passed!");
    };

    // Test 4: transaction_signing_ecdsa_domain_hash
    func test_ecdsa_domain_hash() {
      Debug.print("🧪 Testing transaction_signing_ecdsa_domain_hash...");
      let domain_hash = Sighash.transaction_signing_ecdsa_domain_hash();
      Debug.print("   -> Domain hash: " # hex_from_array(domain_hash));
      Debug.print("   -> Length: " # Nat.toText(domain_hash.size()));
      assert(domain_hash.size() == 32);
      // Expected SHA256("TransactionSigningHashECDSA")
      let expected_hash = array_from_hex("a4f2ece45a286cb1ec0a4e4d383468d000f71757052b1504aa3495328df5f4ea");
      assert(Array.equal(domain_hash, expected_hash, Nat8.equal));
      Debug.print("   ✅ Passed!");
    };

    // Test 5: calculate_sighash_schnorr and calculate_sighash_ecdsa
    // func test_sighash_calculation() {
    //   Debug.print("🧪 Testing sighash calculations...");

    //   let tx: Types.KaspaTransaction = {
    //     version = 0;
    //     inputs = [{
    //       previousOutpoint = {
    //         transactionId = "4ee60f3c7f32bcbef4ae3226da3cdf251172007cb7cf9c99805837cd93855a55";
    //         index = 0;
    //       };
    //       signatureScript = "410a93b358b46ce6c48ead69da05305c08a352cccac837400f8f20b550304f8e273089aae76a30c3b8588361c92e7af4af85388c260121c5866f438e182d365dec01";
    //       sequence = 0;
    //       sigOpCount = 1;
    //     }];
    //     outputs = [{
    //       amount = 400000000; // 4 KAS
    //       scriptPublicKey = {
    //         version = 0;
    //         scriptPublicKey = "210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab";
    //       };
    //     }];
    //     lockTime = 0;
    //     subnetworkId = "0000000000000000000000000000000000000000";
    //     gas = 0;
    //     payload = "";
    //   };

    //   let utxo: Types.UTXO = {
    //     transactionId = "4ee60f3c7f32bcbef4ae3226da3cdf251172007cb7cf9c99805837cd93855a55";
    //     index = 0;
    //     amount = 400010000; // Assume 4 KAS + 0.0001 KAS fee
    //     scriptPublicKey = "20c5ebee2f07e7c3feda1d6e15e83e3cdbd0e0f06eac";
    //     scriptVersion = 0;
    //     address = "kaspa:qypff6urmgk8452vjx55r63dhc38s6ewlavknmnefzgac42n3lt8cdchp86su6n";
    //   };

    //   let reusedValues: Sighash.SighashReusedValues = {
    //     var previousOutputsHash = null;
    //     var sequencesHash = null;
    //     var sigOpCountsHash = null;
    //     var outputsHash = null;
    //     var payloadHash = null;
    //   };

    //     let hashType: Sighash.SigHashType = Sighash.SigHashAll;

    //     let expected_schnorr_hash = array_from_hex("9ada0d0ddc70e95eb5411d1fafafb1956bd0550ff054926753b9ab179b67ca37");
    //     let expected_ecdsa_hash = array_from_hex("3bc12c47f1065469c55c58412d5b6253a570330c7f3d2b0c989bb128bd9f072b");

    //     switch (Sighash.calculate_sighash_schnorr(tx, 0, utxo, hashType, reusedValues)) {
    //         case (null) {
    //             Debug.print("   🚨 Test failed: Schnorr sighash returned null");
    //             assert false;
    //         };
    //         case (?schnorr_hash) {
    //             Debug.print("   -> Schnorr sighash: " # hex_from_array(schnorr_hash));
    //             Debug.print("   -> Length: " # Nat.toText(schnorr_hash.size()));
    //             assert(schnorr_hash.size() == 32);
    //             Debug.print("   -> Expected Schnorr sighash: " # hex_from_array(expected_schnorr_hash));
    //             assert(Array.equal(schnorr_hash, expected_schnorr_hash, Nat8.equal));
    //             Debug.print("   ✅ Schnorr sighash computed!");
    //         };
    //     };

    //     switch (Sighash.calculate_sighash_ecdsa(tx, 0, utxo, hashType, reusedValues)) {
    //         case (null) {
    //             Debug.print("   🚨 Test failed: ECDSA sighash returned null");
    //             assert false;
    //         };
    //         case (?ecdsa_hash) {
    //             Debug.print("   -> ECDSA sighash: " # hex_from_array(ecdsa_hash));
    //             Debug.print("   -> Length: " # Nat.toText(ecdsa_hash.size()));
    //             assert(ecdsa_hash.size() == 32);
    //             Debug.print("   -> Expected ECDSA sighash: " # hex_from_array(expected_ecdsa_hash));
    //             assert(Array.equal(ecdsa_hash, expected_ecdsa_hash, Nat8.equal));
    //             Debug.print("   ✅ ECDSA sighash computed!");
    //         };
    //     };

    //     Debug.print("   ✅ Passed!");
    // };

    // Test 1: test_sighash (adapted from Ledger)
    func test_sighash() {
        Debug.print("🧪 Testing sighash calculation (Ledger test_sighash)...");

        let tx: Types.KaspaTransaction = {
            version = 1;
            inputs = [
                {
                    previousOutpoint = {
                        transactionId = "11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff";
                        index = 1;
                    };
                    signatureScript = "";
                    sequence = 0;
                    sigOpCount = 1;
                }
            ];
            outputs = [
                {
                    amount = 2;
                    scriptPublicKey = {
                        version = 0;
                        scriptPublicKey = "20c62cf30e4e57c5922086460235d5157a62f2666aa22707cb9b588f6211fc0ed6ac";
                    };
                }
            ];
            lockTime = 0;
            subnetworkId = "0000000000000000000000000000000000000000";
            gas = 0;
            payload = "";
        };

        let utxo: Types.UTXO = {
            transactionId = "11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff";
            index = 1;
            amount = 2;
            scriptPublicKey = "20e9edf67a325868ecc7cd8519e6ca5265e65b7d10f56066461ceabf0c2bc1c5adac"; // Matches input_public_key_data
            scriptVersion = 0;
            address = "kaspa:placeholder"; // Placeholder
        };

        let reusedValues: Sighash.SighashReusedValues = {
            var previousOutputsHash = null;
            var sequencesHash = null;
            var sigOpCountsHash = null;
            var outputsHash = null;
            var payloadHash = null;
        };

        let hashType: Sighash.SigHashType = Sighash.SigHashAll;

        // https://github.com/coderofstuff/app-kaspa/blob/develop/unit-tests/test_sighash.c
        let expected_schnorr_hash = array_from_hex("7ccda6c64a181e6263f0eee2edc859dbcd9de717c065ea8e7dce1081bec5baa5");

        switch (Sighash.calculate_sighash_schnorr(tx, 0, utxo, hashType, reusedValues)) {
            case (null) {
                Debug.print("   🚨 Test failed: Schnorr sighash returned null");
                assert false;
            };
            case (?schnorr_hash) {
                Debug.print("   -> Schnorr sighash: " # Sighash.hex_from_array(schnorr_hash));
                Debug.print("   -> Length: " # Nat.toText(schnorr_hash.size()));
                assert(schnorr_hash.size() == 32);
                Debug.print("   -> Expected Schnorr sighash: " # Sighash.hex_from_array(expected_schnorr_hash));
                assert(Array.equal(schnorr_hash, expected_schnorr_hash, Nat8.equal));
                Debug.print("   ✅ Schnorr sighash computed!");
            };
        };

        // from hashlib import sha256
        // domain_hash = bytes.fromhex("a4f2ece45a286cb1ec0a4e4d383468d000f71757052b1504aa3495328df5f4ea")
        // schnorr_hash = bytes.fromhex("7ccda6c64a181e6263f0eee2edc859dbcd9de717c065ea8e7dce1081bec5baa5")  # From test_sighash
        // ecdsa_hash = sha256(domain_hash + schnorr_hash).hexdigest()
        // print("ECDSA sighash:", ecdsa_hash)
        let expected_ecdsa_hash = array_from_hex("07ef78837508fe2ba54d78415c13896fcd40e61cc47125bb46daf967d06d36bf");
        switch (Sighash.calculate_sighash_ecdsa(tx, 0, utxo, hashType, reusedValues)) {
            case (null) {
                Debug.print("   🚨 Test failed: ECDSA sighash returned null");
                assert false;
            };
            case (?ecdsa_hash) {
                Debug.print("   -> ECDSA sighash: " # Sighash.hex_from_array(ecdsa_hash));
                Debug.print("   -> Length: " # Nat.toText(ecdsa_hash.size()));
                assert(ecdsa_hash.size() == 32);
                Debug.print("   -> Expected ECDSA sighash: " # Sighash.hex_from_array(expected_ecdsa_hash));
                assert(Array.equal(ecdsa_hash, expected_ecdsa_hash, Nat8.equal));
                Debug.print("   ✅ ECDSA sighash computed!");
            };
        };

        Debug.print("   ✅ Passed test_sighash!");
    };

    // Test 2: test_sighash_zeros (adapted from Ledger app: https://github.com/coderofstuff/app-kaspa/blob/develop/unit-tests/test_sighash.c)
    func test_sighash_zeros() {
        Debug.print("🧪 Testing sighash calculation (Ledger test_sighash_zeros)...");

        let tx: Types.KaspaTransaction = {
            version = 0;
            inputs = [
                {
                    previousOutpoint = {
                        transactionId = "0000000000000000000000000000000000000000000000000000000000000000";
                        index = 0;
                    };
                    signatureScript = "";
                    sequence = 0;
                    sigOpCount = 1;
                }
            ];
            outputs = [
                {
                    amount = 0;
                    scriptPublicKey = {
                        version = 0;
                        scriptPublicKey = "200000000000000000000000000000000000000000000000000000000000000000ac";
                    };
                }
            ];
            lockTime = 0;
            subnetworkId = "0000000000000000000000000000000000000000";
            gas = 0;
            payload = "";
        };

        let utxo: Types.UTXO = {
            transactionId = "0000000000000000000000000000000000000000000000000000000000000000";
            index = 0;
            amount = 0;
            scriptPublicKey = "200000000000000000000000000000000000000000000000000000000000000000ac";
            scriptVersion = 0;
            address = "kaspa:placeholder"; // Placeholder
        };

        let reusedValues: Sighash.SighashReusedValues = {
            var previousOutputsHash = null;
            var sequencesHash = null;
            var sigOpCountsHash = null;
            var outputsHash = null;
            var payloadHash = null;
        };

        let hashType: Sighash.SigHashType = Sighash.SigHashAll;

        // https://github.com/coderofstuff/app-kaspa/blob/develop/unit-tests/test_sighash.c
        let expected_schnorr_hash = array_from_hex("612d56e633ee5da1caa4563c6ace0c98d3549ad4e3d2b1f1ea6810e6c34047bd");

        switch (Sighash.calculate_sighash_schnorr(tx, 0, utxo, hashType, reusedValues)) {
            case (null) {
                Debug.print("   🚨 Test failed: Schnorr sighash returned null");
                assert false;
            };
            case (?schnorr_hash) {
                Debug.print("   -> Schnorr sighash: " # Sighash.hex_from_array(schnorr_hash));
                Debug.print("   -> Length: " # Nat.toText(schnorr_hash.size()));
                assert(schnorr_hash.size() == 32);
                Debug.print("   -> Expected Schnorr sighash: " # Sighash.hex_from_array(expected_schnorr_hash));
                assert(Array.equal(schnorr_hash, expected_schnorr_hash, Nat8.equal));
                Debug.print("   ✅ Schnorr sighash computed!");
            };
        };

        Debug.print("   ✅ Passed test_sighash_zeros!");
    };

    // Execute all tests
    test_is_standard_sighash_type();
    test_zero_hash();
    test_blake2b_256();
    test_ecdsa_domain_hash();
    test_sighash_zeros();
    test_sighash();

    Debug.print("\n--- All Sighash tests completed! ---\n");
  };
};