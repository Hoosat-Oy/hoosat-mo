import Debug "mo:base/Debug";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Array "mo:base/Array";
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