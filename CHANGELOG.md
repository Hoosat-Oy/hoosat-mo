# Changelog

All notable changes to the Hoosat Motoko package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-09-17

### Added

- **Transaction Broadcasting System**: End-to-end transaction lifecycle support
  - `sendTransaction()` function for complete build → sign → broadcast flow
  - `buildTransaction()` function for building transactions without broadcasting
  - `broadcastSerializedTransaction()` function for broadcasting pre-built transactions
  - `getTransactionStatus()` function for monitoring transaction confirmations
- **Wallet Module** (`src/wallet.mo`): Comprehensive wallet implementation
  - Mainnet and testnet support with factory functions
  - Structured error handling with detailed error types
  - UTXO management with automatic coin selection
  - Balance tracking with confirmed/unconfirmed/immature categorization
  - Address generation with derivation path support
  - Fee estimation and validation
- **Enhanced Error Handling** (`src/errors.mo`): Structured error system
  - `ValidationError` for input validation failures
  - `NetworkError` for API communication issues
  - `CryptographicError` for signing and key generation failures
  - `InsufficientFunds` for transaction funding issues
  - `InternalError` for unexpected system states
- **Input Validation System** (`src/validation.mo`): Comprehensive validation utilities
  - Address format validation with checksum verification
  - Amount validation with dust threshold checking
  - Fee validation with minimum requirements
  - Derivation path validation for BIP44 compliance
  - Hex string validation for script data
- **Enhanced Address Operations** (`src/address_v2.mo`): Improved address handling
  - Better error reporting and validation
  - Enhanced hex encoding/decoding utilities
  - Script generation improvements
- **HTTP Integration**: Direct Hoosat API communication
  - UTXO fetching from `api.Hoosat.org` and `api-testnet.Hoosat.org`
  - Transaction broadcasting with JSON formatting
  - Transaction status monitoring
  - Error handling for network failures
- **Example Implementation** (`examples/wallet_broadcast_example.mo`): Usage demonstration
  - Shows wallet functionality in action
  - Ready-to-deploy canister example
  - Transaction testing capability

### Changed

- **Modern Motoko Syntax**: Updated to use `(with cycles = amount)` syntax instead of deprecated `Cycles.add()`
- **UTXO Parsing**: Enhanced to handle Hoosat API response format with nested `outpoint` and `utxoEntry` structures
- **Signature Script Formatting**: Bitcoin-style script encoding with length prefixes and sighash types
- **JSON Structure**: Corrected transaction broadcast format to match Hoosat node expectations
- **Cycle Management**: Optimized cycle usage for HTTP outcalls and ECDSA operations

### Fixed

- **Transaction Broadcasting**: Resolved JSON formatting issues for successful network submission
- **Signature Validation**: Fixed "signature script is not push only" errors with proper script encoding
- **UTXO Amount Parsing**: Corrected parsing of amount arrays in API responses
- **Error Messages**: Enhanced debugging information for failed operations
- **HTTP Request Format**: Fixed missing/incorrect fields in IC HTTP outcall requests

### Technical Details

- **Tested on Hoosat Mainnet**: Successfully broadcast real transactions
- **IC Integration**: Uses threshold ECDSA with `dfx_test_key` for key management
- **API Compatibility**: Works with Hoosat node REST API v1
- **Cycle Requirements**: ~30B cycles for ECDSA operations, ~230B cycles for HTTP outcalls

### Breaking Changes

- Wallet creation now requires explicit configuration through factory functions
- Error types have been restructured - update error handling code accordingly
- Some function signatures have changed to support the new `Result<T, HoosatError>` return type

### Migration Guide

- Replace direct wallet instantiation with factory functions:
  ```motoko
  // Old: let wallet = Wallet({...config})
  // New: let wallet = Wallet.createMainnetWallet("dfx_test_key")
  ```
- Update error handling to use new structured error types:
  ```motoko
  switch (result) {
    case (#err(#ValidationError({message}))) { /* handle validation error */ };
    case (#err(#NetworkError({message; status_code}))) { /* handle network error */ };
    // ... other error types
  }
  ```

### Dependencies

- Maintains compatibility with existing dependencies: `base`, `blake2b`, `base64`, `sha2`, `json`
- No new external dependencies added

---

## [Previous Versions]

For previous version history, see git commit logs prior to this changelog implementation.
