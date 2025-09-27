# Blake3 Motoko Library

A pure Motoko implementation of the Blake3 cryptographic hash function for the Internet Computer.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Motoko](https://img.shields.io/badge/Motoko-1.0.0-blue.svg)](https://internetcomputer.org/docs/current/developer-docs/build/cdks/motoko-dfinity/motoko)

## Features

- ✅ **Pure Motoko**: No external dependencies, runs entirely in the Motoko runtime
- ✅ **Complete Implementation**: Supports all core Blake3 features
- ✅ **Standard Hashing**: Basic hash function for any input
- ✅ **Keyed Hashing**: Deterministic hashing with secret keys
- ✅ **Incremental Hashing**: Process data in chunks for memory efficiency
- ✅ **Variable Output Length**: XOF (Extendable Output Function) support
- ✅ **Type Safe**: Fully typed with Motoko's type system
- ✅ **Well Tested**: Comprehensive test suite including edge cases

## Installation

### Using dfx (Recommended)

1. Add to your project's dependencies:
```bash
# In your project directory
dfx new my-project
cd my-project
```

2. Copy the `src/Blake3.mo` file to your project's `src/` directory

3. Import in your Motoko code:
```motoko
import Blake3 "Blake3";
```

### Manual Installation

1. Clone or download this repository
2. Copy `src/Blake3.mo` to your project
3. Import the module in your code

## Quick Start

### Basic Hashing
```motoko
import Blake3 "Blake3";

// Hash a text string
let hash = Blake3.hashText("Hello, World!");
let hex = Blake3.toHex(hash);
// hex = "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262"

// Hash raw bytes
let bytes = [1, 2, 3, 4, 5];
let hash2 = Blake3.hash(bytes);
```

### Incremental Hashing
```motoko
// Create a hasher
let hasher = Blake3.hasherInit();

// Add data incrementally
let hasher1 = Blake3.hasherUpdate(hasher, Text.encodeUtf8("Hello"));
let hasher2 = Blake3.hasherUpdate(hasher1, Text.encodeUtf8(" "));
let hasher3 = Blake3.hasherUpdate(hasher2, Text.encodeUtf8("World"));

// Finalize and get the hash
let hash = Blake3.hasherFinalize(hasher3, Blake3.OUT_LEN);
```

### Keyed Hashing
```motoko
// Create a 32-byte key
let key = Array.tabulate<Nat8>(32, func(i) = Nat8.fromNat(i));

// Initialize keyed hasher
let hasher = Blake3.hasherInitKeyed(key);

// Update and finalize
let updatedHasher = Blake3.hasherUpdate(hasher, Text.encodeUtf8("data"));
let hash = Blake3.hasherFinalize(updatedHasher, Blake3.OUT_LEN);
```

### Variable Output Length
```motoko
let hasher = Blake3.hasherInit();
let updatedHasher = Blake3.hasherUpdate(hasher, Text.encodeUtf8("data"));

// Get 16 bytes of output
let shortHash = Blake3.hasherFinalize(updatedHasher, 16);

// Get 64 bytes of output  
let longHash = Blake3.hasherFinalize(updatedHasher, 64);
```

## API Reference

### Constants
- `KEY_LEN`: 32 - Key length in bytes
- `OUT_LEN`: 32 - Default output length in bytes
- `BLOCK_LEN`: 64 - Block length in bytes
- `CHUNK_LEN`: 1024 - Chunk length in bytes

### Main Functions

#### `hasherInit() : Hasher`
Creates a new hasher for standard hashing.

#### `hasherInitKeyed(key: [Nat8]) : Hasher`
Creates a new hasher for keyed hashing with the provided 32-byte key.

#### `hasherUpdate(hasher: Hasher, input: [Nat8]) : Hasher`
Updates the hasher with new input data. Returns a new hasher state.

#### `hasherFinalize(hasher: Hasher, outLen: Nat) : [Nat8]`
Finalizes the hasher and returns the hash output of the specified length.

#### `hasherFinalizeSeek(hasher: Hasher, seek: Nat64, outLen: Nat) : [Nat8]`
Finalizes the hasher with seek functionality for random access to output.

#### `hash(input: [Nat8]) : [Nat8]`
Convenience function for one-shot hashing of byte arrays.

#### `hashText(text: Text) : [Nat8]`
Convenience function for hashing text strings.

#### `toHex(hash: [Nat8]) : Text`
Converts a hash byte array to a hexadecimal string representation.

## Development

### Building
```bash
make build
```

### Testing
```bash
make test
```

### Running Examples
```bash
make demo
```

### Linting
```bash
make lint
```

## Project Structure

```
blake3-motoko/
├── src/
│   ├── Blake3.mo          # Main implementation
│   ├── Blake3Test.mo      # Test suite
│   └── Blake3Example.mo   # Usage examples
├── motoko.toml            # Package configuration
├── dfx.json              # DFX configuration
├── Makefile              # Build automation
├── LICENSE               # MIT License
└── README.md             # This file
```

## Testing

The library includes comprehensive tests:

```motoko
// Run basic tests
let testActor = Blake3Test();
await testActor.runAllTests();

// Run zero-padded key tests
await testActor.runZeroPaddedKeyTests();

// Run comprehensive tests
await testActor.runComprehensiveTests();

// Test key uniqueness
await testActor.testZeroPaddedKeyUniqueness();
```

## Performance Notes

This implementation prioritizes correctness and type safety over raw performance. For maximum performance in production environments, consider:

1. Using the native Blake3 implementation if available
2. Optimizing hot paths based on your specific use case
3. Using incremental hashing for large inputs to avoid memory issues

## Security

This implementation follows the Blake3 specification and should provide the same security guarantees as the reference implementation. However, as with any cryptographic implementation, it's recommended to:

1. Use well-tested, audited implementations for production systems
2. Verify outputs against known test vectors
3. Consider the security implications of the Motoko runtime environment

## Contributing

Contributions are welcome! Please ensure that:

1. All tests pass
2. Code follows Motoko best practices
3. New features include appropriate tests
4. Documentation is updated as needed

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## References

- [Blake3 Specification](https://github.com/BLAKE3-team/BLAKE3-specs)
- [Official Blake3 Repository](https://github.com/BLAKE3-team/BLAKE3)
- [Motoko Documentation](https://internetcomputer.org/docs/current/developer-docs/build/cdks/motoko-dfinity/motoko)
- [Internet Computer Documentation](https://internetcomputer.org/docs)