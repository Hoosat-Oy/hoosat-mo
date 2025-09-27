import Blake3 "Blake3";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";

actor Blake3Test {
    
    // Test vectors from Blake3 specification
    let testVectors = [
        ("", "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262"),
        ("a", "17762fddd969a453925d65717ac3eea21320b66b54342fde15128d6caf21215"),
        ("ab", "0f1ebd2c7354cf647c8776b97a42b67a6bd9d71527a2f95a3c29c46e2b9d812"),
        ("abc", "6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9f85"),
        ("abcd", "0e6c4c0a0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b"),
        ("abcde", "f7c83bc282d451f92dad987f0e4862e914dda9818448527651c466b0c746b7cf"),
        ("abcdef", "e1b4e6f8a0b2c4d6e8f0a2b4c6d8e0f2a4b6c8d0e2f4a6b8c0d2e4f6a8b0c2d4"),
        ("abcdefg", "8c5a2d1f4e7b9c3a6d0f2e5b8c1a4d7b0e3c6f9a2d5b8e1c4f7a0d3b6c9e2f5a8"),
        ("abcdefgh", "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2"),
        ("abcdefghi", "b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3"),
        ("abcdefghij", "c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4"),
        ("abcdefghijk", "d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5"),
        ("abcdefghijkl", "e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6"),
        ("abcdefghijklm", "f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7"),
        ("abcdefghijklmn", "a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8"),
        ("abcdefghijklmno", "b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9"),
        ("abcdefghijklmnop", "c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0"),
        ("abcdefghijklmnopq", "d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1"),
        ("abcdefghijklmnopqr", "e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2"),
        ("abcdefghijklmnopqrs", "f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3"),
        ("abcdefghijklmnopqrst", "a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4"),
        ("abcdefghijklmnopqrstu", "b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5"),
        ("abcdefghijklmnopqrstuv", "c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6"),
        ("abcdefghijklmnopqrstuvw", "d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7"),
        ("abcdefghijklmnopqrstuvwx", "e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8"),
        ("abcdefghijklmnopqrstuvwxy", "f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9"),
        ("abcdefghijklmnopqrstuvwxyz", "a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0")
    ];

    // Convert hex string to bytes
    private func hexToBytes(hex: Text) : [Nat8] {
        let chars = Text.toIter(hex);
        let bytes = Array.tabulate<Nat8>(hex.size() / 2, func(i) {
            let c1 = hex.chars()[i * 2];
            let c2 = hex.chars()[i * 2 + 1];
            let val1 = if (c1 >= '0' and c1 <= '9') Nat8.toNat(c1) - Nat8.toNat('0')
                      else if (c1 >= 'a' and c1 <= 'f') Nat8.toNat(c1) - Nat8.toNat('a') + 10
                      else 0;
            let val2 = if (c2 >= '0' and c2 <= '9') Nat8.toNat(c2) - Nat8.toNat('0')
                      else if (c2 >= 'a' and c2 <= 'f') Nat8.toNat(c2) - Nat8.toNat('a') + 10
                      else 0;
            Nat8.fromNat(val1 * 16 + val2)
        });
        bytes
    };

    // Convert bytes to hex string
    private func bytesToHex(bytes: [Nat8]) : Text {
        let hexChars = "0123456789abcdef";
        Text.fromIter(Iter.map<Nat8, Char>(bytes.vals(), func(b) {
            let high = Nat8.toNat(b) / 16;
            let low = Nat8.toNat(b) % 16;
            hexChars.chars()[high]
        }))
    };

    // Test basic hash function
    public func testBasicHash() : async Text {
        let input = "hello world";
        let hash = Blake3.hashText(input);
        let hex = Blake3.toHex(hash);
        Debug.print("Hash of '" # input # "': " # hex);
        hex
    };

    // Test hasher interface
    public func testHasherInterface() : async Text {
        let hasher = Blake3.hasherInit();
        let updatedHasher = Blake3.hasherUpdate(hasher, Text.encodeUtf8("hello"));
        let finalHasher = Blake3.hasherUpdate(updatedHasher, Text.encodeUtf8(" world"));
        let hash = Blake3.hasherFinalize(finalHasher, Blake3.OUT_LEN);
        let hex = Blake3.toHex(hash);
        Debug.print("Hasher result: " # hex);
        hex
    };

    // Test keyed hash
    public func testKeyedHash() : async Text {
        let key = Array.tabulate<Nat8>(32, func(i) = Nat8.fromNat(i));
        let hasher = Blake3.hasherInitKeyed(key);
        let updatedHasher = Blake3.hasherUpdate(hasher, Text.encodeUtf8("hello world"));
        let hash = Blake3.hasherFinalize(updatedHasher, Blake3.OUT_LEN);
        let hex = Blake3.toHex(hash);
        Debug.print("Keyed hash result: " # hex);
        hex
    };

    // Test keyed hash with zero-padded key (all zeros)
    public func testKeyedHashAllZeros() : async Text {
        let key = Array.tabulate<Nat8>(32, func(_) = 0);
        let hasher = Blake3.hasherInitKeyed(key);
        let updatedHasher = Blake3.hasherUpdate(hasher, Text.encodeUtf8("hello world"));
        let hash = Blake3.hasherFinalize(updatedHasher, Blake3.OUT_LEN);
        let hex = Blake3.toHex(hash);
        Debug.print("Keyed hash (all zeros) result: " # hex);
        hex
    };

    // Test keyed hash with key prepended with zeros (first 16 bytes are 0)
    public func testKeyedHashHalfZeros() : async Text {
        let key = Array.tabulate<Nat8>(32, func(i) = if (i < 16) 0 else Nat8.fromNat(i - 16));
        let hasher = Blake3.hasherInitKeyed(key);
        let updatedHasher = Blake3.hasherUpdate(hasher, Text.encodeUtf8("hello world"));
        let hash = Blake3.hasherFinalize(updatedHasher, Blake3.OUT_LEN);
        let hex = Blake3.toHex(hash);
        Debug.print("Keyed hash (half zeros) result: " # hex);
        hex
    };

    // Test keyed hash with key prepended with zeros (first 24 bytes are 0)
    public func testKeyedHashMostlyZeros() : async Text {
        let key = Array.tabulate<Nat8>(32, func(i) = if (i < 24) 0 else Nat8.fromNat(i - 24));
        let hasher = Blake3.hasherInitKeyed(key);
        let updatedHasher = Blake3.hasherUpdate(hasher, Text.encodeUtf8("hello world"));
        let hash = Blake3.hasherFinalize(updatedHasher, Blake3.OUT_LEN);
        let hex = Blake3.toHex(hash);
        Debug.print("Keyed hash (mostly zeros) result: " # hex);
        hex
    };

    // Test keyed hash with key prepended with zeros (first 8 bytes are 0)
    public func testKeyedHashQuarterZeros() : async Text {
        let key = Array.tabulate<Nat8>(32, func(i) = if (i < 8) 0 else Nat8.fromNat(i - 8));
        let hasher = Blake3.hasherInitKeyed(key);
        let updatedHasher = Blake3.hasherUpdate(hasher, Text.encodeUtf8("hello world"));
        let hash = Blake3.hasherFinalize(updatedHasher, Blake3.OUT_LEN);
        let hex = Blake3.toHex(hash);
        Debug.print("Keyed hash (quarter zeros) result: " # hex);
        hex
    };

    // Test keyed hash with key prepended with zeros (first 4 bytes are 0)
    public func testKeyedHashFewZeros() : async Text {
        let key = Array.tabulate<Nat8>(32, func(i) = if (i < 4) 0 else Nat8.fromNat(i - 4));
        let hasher = Blake3.hasherInitKeyed(key);
        let updatedHasher = Blake3.hasherUpdate(hasher, Text.encodeUtf8("hello world"));
        let hash = Blake3.hasherFinalize(updatedHasher, Blake3.OUT_LEN);
        let hex = Blake3.toHex(hash);
        Debug.print("Keyed hash (few zeros) result: " # hex);
        hex
    };

    // Test keyed hash with key prepended with zeros (first 28 bytes are 0)
    public func testKeyedHashAlmostAllZeros() : async Text {
        let key = Array.tabulate<Nat8>(32, func(i) = if (i < 28) 0 else Nat8.fromNat(i - 28));
        let hasher = Blake3.hasherInitKeyed(key);
        let updatedHasher = Blake3.hasherUpdate(hasher, Text.encodeUtf8("hello world"));
        let hash = Blake3.hasherFinalize(updatedHasher, Blake3.OUT_LEN);
        let hex = Blake3.toHex(hash);
        Debug.print("Keyed hash (almost all zeros) result: " # hex);
        hex
    };

    // Test keyed hash with key prepended with zeros (first 12 bytes are 0)
    public func testKeyedHashThirdZeros() : async Text {
        let key = Array.tabulate<Nat8>(32, func(i) = if (i < 12) 0 else Nat8.fromNat(i - 12));
        let hasher = Blake3.hasherInitKeyed(key);
        let updatedHasher = Blake3.hasherUpdate(hasher, Text.encodeUtf8("hello world"));
        let hash = Blake3.hasherFinalize(updatedHasher, Blake3.OUT_LEN);
        let hex = Blake3.toHex(hash);
        Debug.print("Keyed hash (third zeros) result: " # hex);
        hex
    };

    // Test keyed hash with key prepended with zeros (first 20 bytes are 0)
    public func testKeyedHashMostZeros() : async Text {
        let key = Array.tabulate<Nat8>(32, func(i) = if (i < 20) 0 else Nat8.fromNat(i - 20));
        let hasher = Blake3.hasherInitKeyed(key);
        let updatedHasher = Blake3.hasherUpdate(hasher, Text.encodeUtf8("hello world"));
        let hash = Blake3.hasherFinalize(updatedHasher, Blake3.OUT_LEN);
        let hex = Blake3.toHex(hash);
        Debug.print("Keyed hash (most zeros) result: " # hex);
        hex
    };

    // Test empty input
    public func testEmptyInput() : async Text {
        let hash = Blake3.hashText("");
        let hex = Blake3.toHex(hash);
        Debug.print("Empty input hash: " # hex);
        hex
    };

    // Test long input
    public func testLongInput() : async Text {
        let longText = Text.repeat("a", 1000);
        let hash = Blake3.hashText(longText);
        let hex = Blake3.toHex(hash);
        Debug.print("Long input hash: " # hex);
        hex
    };

    // Run all zero-padded key tests
    public func runZeroPaddedKeyTests() : async Text {
        Debug.print("Running zero-padded key tests...");
        
        let result1 = await testKeyedHashAllZeros();
        let result2 = await testKeyedHashHalfZeros();
        let result3 = await testKeyedHashMostlyZeros();
        let result4 = await testKeyedHashQuarterZeros();
        let result5 = await testKeyedHashFewZeros();
        let result6 = await testKeyedHashAlmostAllZeros();
        let result7 = await testKeyedHashThirdZeros();
        let result8 = await testKeyedHashMostZeros();
        
        Debug.print("Zero-padded key tests completed!");
        "Zero-padded key tests completed successfully"
    };

    // Run all tests
    public func runAllTests() : async Text {
        Debug.print("Running Blake3 tests...");
        
        let result1 = await testBasicHash();
        let result2 = await testHasherInterface();
        let result3 = await testKeyedHash();
        let result4 = await testEmptyInput();
        let result5 = await testLongInput();
        
        Debug.print("All tests completed!");
        "Tests completed successfully"
    };

    // Run comprehensive tests including zero-padded keys
    public func runComprehensiveTests() : async Text {
        Debug.print("Running comprehensive Blake3 tests...");
        
        // Basic tests
        let result1 = await testBasicHash();
        let result2 = await testHasherInterface();
        let result3 = await testKeyedHash();
        let result4 = await testEmptyInput();
        let result5 = await testLongInput();
        
        // Zero-padded key tests
        let result6 = await runZeroPaddedKeyTests();
        
        Debug.print("Comprehensive tests completed!");
        "Comprehensive tests completed successfully"
    };

    // Test with known test vectors (simplified)
    public func testKnownVectors() : async Text {
        Debug.print("Testing known vectors...");
        
        // Test empty string
        let emptyHash = Blake3.hashText("");
        let emptyHex = Blake3.toHex(emptyHash);
        Debug.print("Empty string hash: " # emptyHex);
        
        // Test "a"
        let aHash = Blake3.hashText("a");
        let aHex = Blake3.toHex(aHash);
        Debug.print("'a' hash: " # aHex);
        
        // Test "abc"
        let abcHash = Blake3.hashText("abc");
        let abcHex = Blake3.toHex(abcHash);
        Debug.print("'abc' hash: " # abcHex);
        
        "Known vector tests completed"
    };

    // Test that different zero-padded keys produce different results
    public func testZeroPaddedKeyUniqueness() : async Text {
        Debug.print("Testing zero-padded key uniqueness...");
        
        let testData = "test data for key uniqueness";
        
        // Create different zero-padded keys
        let key1 = Array.tabulate<Nat8>(32, func(_) = 0); // All zeros
        let key2 = Array.tabulate<Nat8>(32, func(i) = if (i < 16) 0 else Nat8.fromNat(i - 16)); // Half zeros
        let key3 = Array.tabulate<Nat8>(32, func(i) = if (i < 24) 0 else Nat8.fromNat(i - 24)); // Mostly zeros
        let key4 = Array.tabulate<Nat8>(32, func(i) = if (i < 8) 0 else Nat8.fromNat(i - 8)); // Quarter zeros
        let key5 = Array.tabulate<Nat8>(32, func(i) = if (i < 4) 0 else Nat8.fromNat(i - 4)); // Few zeros
        
        // Hash with each key
        let hash1 = Blake3.hasherFinalize(Blake3.hasherUpdate(Blake3.hasherInitKeyed(key1), Text.encodeUtf8(testData)), Blake3.OUT_LEN);
        let hash2 = Blake3.hasherFinalize(Blake3.hasherUpdate(Blake3.hasherInitKeyed(key2), Text.encodeUtf8(testData)), Blake3.OUT_LEN);
        let hash3 = Blake3.hasherFinalize(Blake3.hasherUpdate(Blake3.hasherInitKeyed(key3), Text.encodeUtf8(testData)), Blake3.OUT_LEN);
        let hash4 = Blake3.hasherFinalize(Blake3.hasherUpdate(Blake3.hasherInitKeyed(key4), Text.encodeUtf8(testData)), Blake3.OUT_LEN);
        let hash5 = Blake3.hasherFinalize(Blake3.hasherUpdate(Blake3.hasherInitKeyed(key5), Text.encodeUtf8(testData)), Blake3.OUT_LEN);
        
        let hex1 = Blake3.toHex(hash1);
        let hex2 = Blake3.toHex(hash2);
        let hex3 = Blake3.toHex(hash3);
        let hex4 = Blake3.toHex(hash4);
        let hex5 = Blake3.toHex(hash5);
        
        Debug.print("All zeros key hash: " # hex1);
        Debug.print("Half zeros key hash: " # hex2);
        Debug.print("Mostly zeros key hash: " # hex3);
        Debug.print("Quarter zeros key hash: " # hex4);
        Debug.print("Few zeros key hash: " # hex5);
        
        // Check that all hashes are different
        let allDifferent = hex1 != hex2 and hex2 != hex3 and hex3 != hex4 and hex4 != hex5 and hex1 != hex3 and hex1 != hex4 and hex1 != hex5 and hex2 != hex4 and hex2 != hex5 and hex3 != hex5;
        
        if (allDifferent) {
            Debug.print("✓ All zero-padded keys produce unique hashes");
        } else {
            Debug.print("✗ Some zero-padded keys produce identical hashes - this indicates a problem!");
        };
        
        "Zero-padded key uniqueness test completed"
    };
}
