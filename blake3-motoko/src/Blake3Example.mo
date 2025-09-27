import Blake3 "Blake3";
import Text "mo:base/Text";
import Debug "mo:base/Debug";

actor Blake3Example {
    
    // Simple hash example
    public func hashText(text: Text) : async Text {
        let hash = Blake3.hashText(text);
        Blake3.toHex(hash)
    };

    // Hash bytes
    public func hashBytes(bytes: [Nat8]) : async Text {
        let hash = Blake3.hash(bytes);
        Blake3.toHex(hash)
    };

    // Incremental hashing example
    public func incrementalHash() : async Text {
        let hasher = Blake3.hasherInit();
        
        // Add data in chunks
        let hasher1 = Blake3.hasherUpdate(hasher, Text.encodeUtf8("Hello"));
        let hasher2 = Blake3.hasherUpdate(hasher1, Text.encodeUtf8(" "));
        let hasher3 = Blake3.hasherUpdate(hasher2, Text.encodeUtf8("World"));
        
        // Finalize
        let hash = Blake3.hasherFinalize(hasher3, Blake3.OUT_LEN);
        Blake3.toHex(hash)
    };

    // Keyed hashing example
    public func keyedHash(key: [Nat8], data: Text) : async Text {
        let hasher = Blake3.hasherInitKeyed(key);
        let updatedHasher = Blake3.hasherUpdate(hasher, Text.encodeUtf8(data));
        let hash = Blake3.hasherFinalize(updatedHasher, Blake3.OUT_LEN);
        Blake3.toHex(hash)
    };

    // Demonstrate different output lengths
    public func variableOutputLength(data: Text, length: Nat) : async Text {
        let hasher = Blake3.hasherInit();
        let updatedHasher = Blake3.hasherUpdate(hasher, Text.encodeUtf8(data));
        let hash = Blake3.hasherFinalize(updatedHasher, length);
        Blake3.toHex(hash)
    };

    // Example usage
    public func demonstrateUsage() : async Text {
        Debug.print("=== Blake3 Motoko Implementation Demo ===");
        
        // Simple hash
        let simpleHash = await hashText("Hello, Blake3!");
        Debug.print("Simple hash: " # simpleHash);
        
        // Incremental hash
        let incrementalHash = await incrementalHash();
        Debug.print("Incremental hash: " # incrementalHash);
        
        // Keyed hash
        let key = Array.tabulate<Nat8>(32, func(i) = Nat8.fromNat(i));
        let keyedHash = await keyedHash(key, "Secret message");
        Debug.print("Keyed hash: " # keyedHash);
        
        // Variable output length
        let shortHash = await variableOutputLength("Test data", 16);
        Debug.print("Short hash (16 bytes): " # shortHash);
        
        let longHash = await variableOutputLength("Test data", 64);
        Debug.print("Long hash (64 bytes): " # longHash);
        
        "Demo completed successfully!"
    };
}
