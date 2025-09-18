# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Motoko package (`kaspa-mo`) and canister implementation for interacting with the Kaspa blockchain on the Internet Computer (IC). The project provides utilities for generating Kaspa addresses, calculating signature hashes, building transactions, and signing them using IC's threshold ECDSA.

## Commands

### Development Commands
- `mops install` - Install package dependencies
- `dfx start --background` - Start the IC replica locally
- `dfx deploy` - Deploy the canister to local replica
- `dfx stop` - Stop the local replica

### Testing
- Tests are located in the `test/` directory as individual `.mo` files
- Run tests by calling the following command in the root directory: `mops test <test_file_name>` to run specific test or `mops test` to run all tests in the `test/` directory
- Tests use a custom assertion framework with `assertEqual` functions
- Test files: `address.test.mo`, `sighash.test.mo`, `transaction.test.mo`, `personal_message.test.mo`

### Package Management
- Uses Mops package manager for dependencies
- Configuration in `mops.toml`
- Dependencies: `base`, `blake2b`, `base64`, `sha2`, `json`

## Architecture

### Core Library Structure (`src/`)
The library is organized into focused modules:

#### Production Modules (Recommended for new development)
- **`errors.mo`** - Comprehensive error handling with structured error types
- **`validation.mo`** - Input validation and security checks
- **`address_v2.mo`** - Enhanced address operations with proper error handling
- **`wallet.mo`** - Wallet functionality with comprehensive features

#### Legacy Modules (Maintained for backward compatibility)
- **`types.mo`** - Core data structures (KaspaTransaction, UTXO, TransactionInput/Output)
- **`address.mo`** - Basic address generation and validation using CashAddr format
- **`sighash.mo`** - Signature hash calculation for Schnorr and ECDSA signatures
- **`transaction.mo`** - Basic transaction building and serialization
- **`personal_message.mo`** - Personal message signing utilities

### Canister Implementation (`src/kaspa_test_tecdsa/`)
- **`main.mo`** - Example canister demonstrating ECDSA integration with IC management canister
- Uses `dfx_test_key` for threshold ECDSA operations
- Implements UTXO fetching, address generation, and transaction signing

### Address Types
The library supports three Kaspa address types:
- `SCHNORR = 0` - For 32-byte Schnorr public keys
- `ECDSA = 1` - For 33-byte ECDSA public keys
- `P2SH = 2` - For 32-byte script hashes

### Signature Hash Types
Supports standard Kaspa sighash types:
- `SigHashAll = 0x01` - Signs all inputs and outputs
- `SigHashNone = 0x02` - Signs inputs only
- `SigHashSingle = 0x04` - Signs inputs and one output
- `SigHashAnyOneCanPay = 0x80` - Signs only current input

### Transaction Building
- Transactions use one input (UTXO) and 1-2 outputs (recipient + optional change)
- Dust threshold: 1,000 sompi minimum for outputs
- Default transaction version: 0
- Empty subnetwork ID for mainnet transactions

## Development Notes

### IC Integration
- Canister requires `dfx_test_key` access for ECDSA operations
- Cycle requirements: ~30B for signing, ~230B for HTTP outcalls
- Uses IC management canister (`ic:aaaaa-aa`) for ECDSA operations

### Testing Patterns
- Tests use persistent actors for state management
- Custom assertion functions with emoji status indicators (✅/❌)
- Type-specific equality and toString functions for test output
- Test data includes real Kaspa mainnet transaction examples

### Import Patterns

#### Production Imports (Recommended for new development)
For library usage (after `mops add kaspa`):
```motoko
import Result "mo:base/Result";
import Errors "mo:kaspa/errors";
import Validation "mo:kaspa/validation";
import Address "mo:kaspa/address";
import Wallet "mo:kaspa/wallet";
```

For local development:
```motoko
import Errors "../src/errors";
import Validation "../src/validation";
import Address "../src/address";
import Wallet "../src/wallet";
```

#### Legacy Imports (Backward compatibility)
For library usage (after `mops add kaspa`):
```motoko
import Address "mo:kaspa/kaspa_legacy/address";
import Sighash "mo:kaspa/kaspa_legacy/sighash";
import Transaction "mo:kaspa/kaspa_legacy/transaction";
import Types "mo:kaspa/kaspa_legacy/types";
```

For local development:
```motoko
import Address "../kaspa/address";
import Types "../kaspa/types";
```

### Key Constants
- Kaspa sompi (smallest unit): 1 KAS = 100,000,000 sompi
- Dust threshold: 1,000 sompi
- Address prefix: "kaspa:"
- Transaction version: 0
- Default subnetwork ID: "0000000000000000000000000000000000000000"

### Security Considerations
- Private keys are handled by IC's threshold ECDSA, never stored in canister
- All cryptographic operations use vetted libraries (`blake2b`, `sha2`)
- Transaction serialization follows Kaspa's exact JSON API format
- Address validation includes checksum verification