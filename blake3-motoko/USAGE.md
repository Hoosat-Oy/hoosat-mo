# Blake3 Motoko Library - Usage Guide

This guide provides detailed examples of how to use the Blake3 Motoko library in your projects.

## Table of Contents

1. [Basic Usage](#basic-usage)
2. [Incremental Hashing](#incremental-hashing)
3. [Keyed Hashing](#keyed-hashing)
4. [Variable Output Length](#variable-output-length)
5. [Error Handling](#error-handling)
6. [Performance Tips](#performance-tips)
7. [Common Patterns](#common-patterns)

## Basic Usage

### Simple Text Hashing

```motoko
import Blake3 "Blake3";

actor MyActor {
    public func hashText(text: Text) : async Text {
        let hash = Blake3.hashText(text);
        Blake3.toHex(hash)
    };
    
    // Example usage
    public func example() : async Text {
        let result = await hashText("Hello, World!");
        // Returns: "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262"
        result
    };
}
```

### Byte Array Hashing

```motoko
import Blake3 "Blake3";
import Array "mo:base/Array";

actor MyActor {
    public func hashBytes(bytes: [Nat8]) : async Text {
        let hash = Blake3.hash(bytes);
        Blake3.toHex(hash)
    };
    
    // Example with specific bytes
    public func example() : async Text {
        let data = [1, 2, 3, 4, 5, 6, 7, 8];
        let result = await hashBytes(data);
        result
    };
}
```

## Incremental Hashing

Use incremental hashing when you need to process large amounts of data or when data arrives in chunks.

```motoko
import Blake3 "Blake3";
import Text "mo:base/Text";

actor MyActor {
    public func processLargeData(chunks: [Text]) : async Text {
        let hasher = Blake3.hasherInit();
        
        // Process each chunk
        var currentHasher = hasher;
        for (chunk in chunks.vals()) {
            let bytes = Text.encodeUtf8(chunk);
            currentHasher := Blake3.hasherUpdate(currentHasher, bytes);
        };
        
        // Finalize and get the hash
        let hash = Blake3.hasherFinalize(currentHasher, Blake3.OUT_LEN);
        Blake3.toHex(hash)
    };
    
    // Example with multiple chunks
    public func example() : async Text {
        let chunks = ["Hello", " ", "World", "!"];
        let result = await processLargeData(chunks);
        result
    };
}
```

## Keyed Hashing

Keyed hashing is useful for creating deterministic hashes with a secret key, commonly used for authentication and message integrity.

```motoko
import Blake3 "Blake3";
import Array "mo:base/Array";
import Text "mo:base/Text";

actor MyActor {
    // Create a key from a string (for demonstration)
    private func createKey(keyString: Text) : [Nat8] {
        let bytes = Text.encodeUtf8(keyString);
        // Pad or truncate to exactly 32 bytes
        if (bytes.size() >= 32) {
            Array.tabulate<Nat8>(32, func(i) = bytes[i])
        } else {
            let padded = Array.tabulate<Nat8>(32, func(i) {
                if (i < bytes.size()) bytes[i] else 0
            });
            padded
        }
    };
    
    public func keyedHash(keyString: Text, data: Text) : async Text {
        let key = createKey(keyString);
        let hasher = Blake3.hasherInitKeyed(key);
        let updatedHasher = Blake3.hasherUpdate(hasher, Text.encodeUtf8(data));
        let hash = Blake3.hasherFinalize(updatedHasher, Blake3.OUT_LEN);
        Blake3.toHex(hash)
    };
    
    // Example usage
    public func example() : async Text {
        let result = await keyedHash("my-secret-key", "sensitive data");
        result
    };
}
```

## Variable Output Length

Blake3 supports generating hashes of arbitrary length using the XOF (Extendable Output Function) feature.

```motoko
import Blake3 "Blake3";
import Text "mo:base/Text";

actor MyActor {
    public func generateHash(data: Text, length: Nat) : async Text {
        let hasher = Blake3.hasherInit();
        let updatedHasher = Blake3.hasherUpdate(hasher, Text.encodeUtf8(data));
        let hash = Blake3.hasherFinalize(updatedHasher, length);
        Blake3.toHex(hash)
    };
    
    // Generate different length hashes
    public func example() : async [Text] {
        let data = "Hello, World!";
        let shortHash = await generateHash(data, 16);  // 16 bytes
        let mediumHash = await generateHash(data, 32); // 32 bytes (default)
        let longHash = await generateHash(data, 64);   // 64 bytes
        
        [shortHash, mediumHash, longHash]
    };
}
```

## Error Handling

While the Blake3 implementation is designed to be robust, here are some best practices for error handling:

```motoko
import Blake3 "Blake3";
import Text "mo:base/Text";
import Result "mo:base/Result";

actor MyActor {
    public type HashResult = Result.Result<Text, Text>;
    
    public func safeHash(data: Text) : async HashResult {
        if (data.size() == 0) {
            return #err("Empty input data");
        };
        
        try {
            let hash = Blake3.hashText(data);
            let hex = Blake3.toHex(hash);
            #ok(hex)
        } catch (e) {
            #err("Hash computation failed: " # Error.message(e))
        }
    };
    
    // Example with error handling
    public func example() : async Text {
        switch (await safeHash("test data")) {
            case (#ok(hash)) { "Hash: " # hash };
            case (#err(error)) { "Error: " # error };
        }
    };
}
```

## Performance Tips

### 1. Use Incremental Hashing for Large Data

```motoko
// Good: For large data
let hasher = Blake3.hasherInit();
let updatedHasher = Blake3.hasherUpdate(hasher, largeData);
let hash = Blake3.hasherFinalize(updatedHasher, Blake3.OUT_LEN);

// Avoid: For very large data (may cause memory issues)
let hash = Blake3.hash(veryLargeData);
```

### 2. Reuse Hashers When Possible

```motoko
// Good: Reuse hasher for multiple operations
let hasher = Blake3.hasherInit();
let hasher1 = Blake3.hasherUpdate(hasher, data1);
let hasher2 = Blake3.hasherUpdate(hasher, data2);
let hash = Blake3.hasherFinalize(hasher2, Blake3.OUT_LEN);
```

### 3. Use Appropriate Output Lengths

```motoko
// Use shorter hashes when you don't need full 32 bytes
let shortHash = Blake3.hasherFinalize(hasher, 16);  // 16 bytes
let fullHash = Blake3.hasherFinalize(hasher, 32);   // 32 bytes (default)
```

## Common Patterns

### 1. File Hashing

```motoko
import Blake3 "Blake3";
import Text "mo:base/Text";

actor FileHasher {
    public func hashFileContent(content: Text) : async Text {
        let hasher = Blake3.hasherInit();
        let updatedHasher = Blake3.hasherUpdate(hasher, Text.encodeUtf8(content));
        let hash = Blake3.hasherFinalize(updatedHasher, Blake3.OUT_LEN);
        Blake3.toHex(hash)
    };
}
```

### 2. Message Authentication

```motoko
import Blake3 "Blake3";
import Array "mo:base/Array";

actor MessageAuth {
    private let secretKey = Array.tabulate<Nat8>(32, func(i) = Nat8.fromNat(i));
    
    public func createMac(message: Text) : async Text {
        let hasher = Blake3.hasherInitKeyed(secretKey);
        let updatedHasher = Blake3.hasherUpdate(hasher, Text.encodeUtf8(message));
        let mac = Blake3.hasherFinalize(updatedHasher, Blake3.OUT_LEN);
        Blake3.toHex(mac)
    };
    
    public func verifyMac(message: Text, expectedMac: Text) : async Bool {
        let computedMac = await createMac(message);
        computedMac == expectedMac
    };
}
```

### 3. Data Integrity Checking

```motoko
import Blake3 "Blake3";
import Text "mo:base/Text";

actor DataIntegrity {
    public func computeChecksum(data: Text) : async Text {
        let hash = Blake3.hashText(data);
        Blake3.toHex(hash)
    };
    
    public func verifyIntegrity(data: Text, expectedChecksum: Text) : async Bool {
        let computedChecksum = await computeChecksum(data);
        computedChecksum == expectedChecksum
    };
}
```

### 4. Password Hashing (with Salt)

```motoko
import Blake3 "Blake3";
import Text "mo:base/Text";
import Array "mo:base/Array";

actor PasswordHasher {
    public func hashPassword(password: Text, salt: Text) : async Text {
        let combined = password # salt;
        let hasher = Blake3.hasherInit();
        let updatedHasher = Blake3.hasherUpdate(hasher, Text.encodeUtf8(combined));
        let hash = Blake3.hasherFinalize(updatedHasher, Blake3.OUT_LEN);
        Blake3.toHex(hash)
    };
    
    public func verifyPassword(password: Text, salt: Text, expectedHash: Text) : async Bool {
        let computedHash = await hashPassword(password, salt);
        computedHash == expectedHash
    };
}
```

## Testing Your Implementation

Always test your Blake3 usage with known test vectors:

```motoko
import Blake3 "Blake3";

actor TestActor {
    public func testKnownVectors() : async Bool {
        // Test empty string
        let emptyHash = Blake3.hashText("");
        let emptyHex = Blake3.toHex(emptyHash);
        
        // Test "abc"
        let abcHash = Blake3.hashText("abc");
        let abcHex = Blake3.toHex(abcHash);
        
        // Verify against known values (you should use actual test vectors)
        emptyHex != "" and abcHex != ""
    };
}
```

This usage guide should help you integrate Blake3 into your Motoko projects effectively. For more advanced usage patterns, refer to the main README.md file.
