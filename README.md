# Hoosat Motoko Package and Canister

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![mops](https://oknww-riaaa-aaaam-qaf6a-cai.raw.ic0.app/badge/mops/Hoosat)](https://mops.one/Hoosat)

Welcome to the `hoosat-mo` project, which provides a Motoko package (`hoosat-mo`) and a canister implementation for interacting with the Hoosat blockchain on the Internet Computer (IC). The `Hoosat-mo` package includes modules for generating and decoding Hoosat addresses, calculating signature hashes, building and serializing transactions, and defining common blockchain data structures. The `hoosat_ecdsa.mo` canister demonstrates how to use the package to fetch UTXOs, generate addresses, and sign ECDSA-based transactions.

## Table of Contents

- [Installation](#installation)
  - [For Library Usage (Mops)](#for-library-usage-mops)
  - [For Canister Development (DFX)](#for-canister-development-dfx)
- [Dependencies](#dependencies)
- [Running the Canister Locally](#running-the-canister-locally)
  - [Note on Frontend Environment Variables](#note-on-frontend-environment-variables)
- [Examples](#examples)
  - [Internet Identity + Hoosat Wallet](#internet-identity--Hoosat-wallet)
  - [Basic Wallet Broadcasting](#basic-wallet-broadcasting)
- [Usage](#usage)
  - [Example: Generating a Hoosat Address](#example-generating-a-Hoosat-address)
  - [Example: Calculating a Schnorr Sighash](#example-calculating-a-schnorr-sighash)
  - [Example: Building a Transaction](#example-building-a-transaction)
- [Example Canister](#example-canister)
  - [Key Functions](#key-functions)
  - [Dependencies](#dependencies-1)
  - [Notes](#notes)
- [Modules](#modules)
  - [address.mo](#addressmo)
  - [sighash.mo](#sighashmo)
  - [transaction.mo](#transactionmo)
  - [types.mo](#typesmo)
- [Contributing](#contributing)
- [License](#license)
- [Additional Resources](#additional-resources)

## Installation

### For Library Usage (Mops)

To use the `Hoosat-mo` package in your Motoko project:

1. **Install Mops** (if not already installed):

   ```bash
   npm i -g ic-mops
   ```

2. **Add the Hoosat package** to your project:

   ```bash
   mops add Hoosat
   ```

3. **For DFX projects**:
   Add the following to your `dfx.json` under `defaults.build.packtool`:
   ```json
   "mops sources"
   ```

### For Canister Development (DFX)

To work with the `Hoosat` canister project locally:

1. **Install DFX** (if not already installed):
   Follow the [SDK Developer Tools](https://internetcomputer.org/docs/current/developer-docs/setup/install) guide.

2. **Clone the repository**:

   ```bash
   git clone https://github.com/codecustard/Hoosat
   cd Hoosat
   ```

3. **Install dependencies**:
   ```bash
   mops install
   ```

## Dependencies

The `Hoosat-mo` package and `Hoosat` canister depend on:

- `mo:blake2b`: For Blake2b-256 hashing in `sighash.mo`.
- `mo:sha2`: For SHA-256 hashing in `sighash.mo`.
- `mo:json`: For parsing JSON responses in `hoosat_ecdsa.mo`.

This package can be added via [mops.one](https://mops.one/Hoosat):

```bash
mops add Hoosat
```

The canister also uses the IC management canister (`ic:aaaaa-aa`) for ECDSA operations, requiring sufficient cycles and permissions.

## Running the Canister Locally

To test the `Hoosat` canister locally:

1. **Start the replica**:

   ```bash
   dfx start --background
   ```

2. **Deploy the canister**:

   ```bash
   dfx deploy
   ```

   This deploys the `hoosat_ecdsa.mo` canister and generates its Candid interface. The canister will be available at `http://localhost:4943?canisterId=<asset_canister_id>`.

3. **Generate the Candid interface** (if backend changes are made):
   ```bash
   npm run generate
   ```

## Examples

This repository includes comprehensive examples demonstrating different use cases for the Hoosat Motoko package:

## Usage

Import the `Hoosat-mo` modules in your Motoko code:

```motoko
import Address "mo:Hoosat-mo/address";
import Wallet "mo:Hoosat-mo/wallet";
import Errors "mo:Hoosat-mo/errors";
import Validation "mo:Hoosat-mo/validation";
```

### Example: Generating a Hoosat Address

Generate a Hoosat address from a public key (Schnorr or ECDSA):

```motoko
import Address "mo:Hoosat-mo/address";
import Result "mo:base/Result";
import Blob "mo:base/Blob";

actor {
  public func generateAddress(pubkeyHex : Text, addrType : Nat) : async Text {
    switch (Address.arrayFromHex(pubkeyHex)) {
      case (#ok(pubkey)) {
        switch (Address.generateAddress(Blob.fromArray(pubkey), addrType)) {
          case (#ok(info)) { info.address };
          case (#err(_)) { "" };
        }
      };
      case (#err(_)) { "" };
    }
  };
};
```

Example call:

- Schnorr (32-byte pubkey): `generateAddress("a1b2c3d4e5f6...64chars", Address.SCHNORR)` → `Hoosat:qypq...`
- ECDSA (33-byte pubkey): `generateAddress("02a1b2c3d4e5...66chars", Address.ECDSA)` → `Hoosat:qypq...`

### Example: Calculating a Schnorr Sighash

Calculate a signature hash for a Hoosat transaction input:

```motoko
import Sighash "mo:codecustard/Hoosat/src/sighash";
import Types "mo:codecustard/Hoosat/src/types";

actor {
  public func calculateSighash(tx : Types.HoosatTransaction, inputIndex : Nat, utxo : Types.UTXO) : async ?Text {
    let reusedValues : Sighash.SighashReusedValues = {
      var previousOutputsHash = null;
      var sequencesHash = null;
      var sigOpCountsHash = null;
      var outputsHash = null;
      var payloadHash = null;
    };
    switch (Sighash.calculate_sighash_schnorr(tx, inputIndex, utxo, Sighash.SigHashAll, reusedValues)) {
      case (?hash) { ?Sighash.hex_from_array(hash) };
      case (null) { null };
    }
  };
};
```

### Example: Building a Transaction

Build a Hoosat transaction with one input and one or two outputs:

```motoko
import Transaction "mo:codecustard/Hoosat/src/transaction";
import Types "mo:codecustard/Hoosat/src/types";

actor {
  public func createTransaction(
    utxo : Types.UTXO,
    recipientScript : Text,
    amount : Nat64,
    fee : Nat64,
    changeScript : Text
  ) : async Text {
    let tx = Transaction.build_transaction(utxo, recipientScript, amount, fee, changeScript);
    Transaction.serialize_transaction(tx)
  };
};
```

Example call:

```motoko
let utxo : Types.UTXO = {
  transactionId = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6";
  index = 0;
  amount = 2000000;
  scriptVersion = 0;
  scriptPublicKey = "20a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3ac";
  address = "Hoosat:qypq...";
};
let json = await createTransaction(utxo, "20d4e5f6a1b2c3...ac", 1000000, 1000, "20a1b2c3d4e5f6...ac");
// Returns JSON: "{\"transaction\":{\"version\":0,\"inputs\":[...],\"outputs\":[...],...}}"
```

## Example Canister

The `hoosat_ecdsa.mo` canister demonstrates how to use the `Hoosat-mo` package to interact with the Hoosat blockchain. It fetches UTXOs from the Hoosat mainnet, generates ECDSA-based addresses, builds transactions, and signs them using the Internet Computer’s management canister (`aaaaa-aa`) for ECDSA operations. The canister is configured for ECDSA transactions and uses the `dfx_test_key` for signing.

### Key Functions

- `get_hoosat_address(derivation_path : ?Text) : async Text`

  - Retrieves an ECDSA public key from the IC management canister and converts it to a Hoosat address.
  - Supports optional derivation paths (e.g., `"44'/111111'/0'/0/0"`).
  - Example:
    ```motoko
    let addr = await get_hoosat_address(?"44'/111111'/0'/0/0");
    // Returns: "Hoosat:qypq..."
    ```

- `send_hoosat(recipient_address : Text, amount : Nat64) : async ?Text`
  - Builds, signs, and serializes a transaction to send `amount` sompi to `recipient_address`.
  - Fetches UTXOs from the Hoosat mainnet, selects one with sufficient funds, and creates a transaction with a recipient output and optional change output.
  - Signs the transaction using ECDSA with `SigHashAll`.
  - Returns the serialized transaction JSON or `null` on failure (e.g., invalid address, insufficient funds).
  - Example:
    ```motoko
    let result = await send_hoosat("Hoosat:qypq...", 1000000);
    switch (result) {
      case (?json) { /* JSON-serialized transaction */ };
      case (null) { /* Failed to create transaction */ };
    };
    ```

### Dependencies

- Requires `mo:json` for parsing UTXO responses from the Hoosat API.
- Uses the IC management canister (`ic:aaaaa-aa`) for ECDSA public key retrieval and signing.

### Notes

- The canister requires access to the `dfx_test_key` for ECDSA operations. Ensure the canister has sufficient cycles (e.g., 30B for signing, 230B for HTTP requests) and permissions for `aaaaa-aa`.
- The `submit_transaction` function is a placeholder (commented out). To submit transactions, implement an HTTP request to the Hoosat API (e.g., `https://api.Hoosat.org/transactions`).
- The canister fetches UTXOs from `api.Hoosat.org`. Handle potential API rate limits or errors (e.g., via retry logic).

## Modules

### `address.mo`

Provides functions for encoding and decoding Hoosat addresses using the CashAddr format, converting public keys to script public keys, and handling hex conversions.

#### Constants

- `SCHNORR : Nat = 0`: Represents Schnorr-based addresses (32-byte payload).
- `ECDSA : Nat = 1`: Represents ECDSA-based addresses (33-byte payload).
- `P2SH : Nat = 2`: Represents Pay-to-Script-Hash addresses (32-byte payload).
- `SCHNORR_PAYLOAD_LEN : Nat = 32`: Expected length for Schnorr/P2SH payloads.
- `ECDSA_PAYLOAD_LEN : Nat = 33`: Expected length for ECDSA payloads.

#### Public Functions

- `address_from_pubkey(pubkey : Blob, addr_type : Nat) : Text`

  - Generates a Hoosat address (`Hoosat:...`) from a public key blob for the specified address type (`SCHNORR`, `ECDSA`, or `P2SH`).
  - Returns an empty string if the public key length is invalid or encoding fails.
  - Example:
    ```motoko
    let pubkey = Blob.fromArray([0xa1, 0xb2, ...]); // 32 or 33 bytes
    let address = Address.address_from_pubkey(pubkey, Address.SCHNORR);
    // Returns: "Hoosat:qypq..."
    ```

- `pubkey_to_script(pubkey : [Nat8], addr_type : Nat) : Text`

  - Converts a public key to a hex-encoded script public key (e.g., for P2PK Schnorr or ECDSA).
  - Schnorr: `OP_DATA_32 <pubkey> OP_CHECKSIG`.
  - ECDSA: `OP_DATA_33 <pubkey> OP_CHECKSIG`.
  - Returns an empty string if the address type or public key length is invalid.
  - Example:
    ```motoko
    let pubkey = Address.array_from_hex("a1b2c3...");
    let script = Address.pubkey_to_script(pubkey, Address.SCHNORR);
    // Returns: "20<32-byte-pubkey>ac"
    ```

- `decode_address(address : Text) : ?(Nat, [Nat8])`

  - Decodes a Hoosat address (`Hoosat:...`) into its address type (`SCHNORR`, `ECDSA`, or `P2SH`) and payload bytes.
  - Validates the address prefix, charset, checksum, and payload length.
  - Returns `null` if the address is invalid.
  - Example:
    ```motoko
    switch (Address.decode_address("Hoosat:qypq...")) {
      case (? (addrType, payload)) {
        // addrType: 0 (SCHNORR), payload: [Nat8] of length 32
      };
      case (null) { /* Invalid address */ };
    };
    ```

- `hex_from_array(bytes : [Nat8]) : Text`

  - Converts a byte array to a lowercase hex string.
  - Example: `[0xa1, 0xb2]` → `"a1b2"`.

- `array_from_hex(hex : Text) : [Nat8]`
  - Converts a hex string (lowercase or uppercase) to a byte array.
  - Returns an empty array if the hex string is invalid.
  - Example: `"a1b2"` → `[0xa1, 0xb2]`.

### `sighash.mo`

Provides functions for calculating signature hashes (sighash) for Hoosat transactions, supporting both Schnorr and ECDSA signatures. It includes utilities for handling transaction data and optimizing hash calculations with reused values.

#### Types

- `SigHashType : Nat8`: Represents the sighash type for transaction signing.
- `SighashReusedValues`: A record to cache precomputed hashes for efficiency:
  ```motoko
  {
    var previousOutputsHash: ?[Nat8];
    var sequencesHash: ?[Nat8];
    var sigOpCountsHash: ?[Nat8];
    var outputsHash: ?[Nat8];
    var payloadHash: ?[Nat8];
  }
  ```

#### Constants

- `SigHashAll : Nat8 = 0x01`: Signs all inputs and outputs.
- `SigHashNone : Nat8 = 0x02`: Signs all inputs, no outputs.
- `SigHashSingle : Nat8 = 0x04`: Signs all inputs and one output.
- `SigHashAnyOneCanPay : Nat8 = 0x80`: Signs only the current input.
- `SigHashAll_AnyOneCanPay : Nat8 = 0x81`: Combines `SigHashAll` with `AnyOneCanPay`.
- `SigHashNone_AnyOneCanPay : Nat8 = 0x82`: Combines `SigHashNone` with `AnyOneCanPay`.
- `SigHashSingle_AnyOneCanPay : Nat8 = 0x84`: Combines `SigHashSingle` with `AnyOneCanPay`.
- `SigHashMask : Nat8 = 0x07`: Mask for extracting the base sighash type.

#### Public Functions

- `is_standard_sighash_type(hashType : SigHashType) : Bool`

  - Checks if the provided sighash type is standard (e.g., `SigHashAll`, `SigHashNone`).
  - Example:
    ```motoko
    let isValid = Sighash.is_standard_sighash_type(Sighash.SigHashAll); // true
    ```

- `calculate_sighash_schnorr(tx : Types.HoosatTransaction, input_index : Nat, utxo : Types.UTXO, hashType : SigHashType, reusedValues : SighashReusedValues) : ?[Nat8]`

  - Calculates the Schnorr sighash for a transaction input, using Blake2b-256 with a domain separator.
  - Returns `null` if the sighash type is invalid or input index is out of bounds.
  - Example:
    ```motoko
    let reusedValues : Sighash.SighashReusedValues = { var previousOutputsHash = null; ... };
    switch (Sighash.calculate_sighash_schnorr(tx, 0, utxo, Sighash.SigHashAll, reusedValues)) {
      case (?hash) { Sighash.hex_from_array(hash) }; // Hex-encoded sighash
      case (null) { /* Invalid input */ };
    };
    ```

- `calculate_sighash_ecdsa(tx : Types.HoosatTransaction, input_index : Nat, utxo : Types.UTXO, hashType : SigHashType, reusedValues : SighashReusedValues) : ?[Nat8]`

  - Calculates the ECDSA sighash by hashing the Schnorr sighash with SHA-256 and an ECDSA domain separator.
  - Returns `null` if the Schnorr sighash calculation fails.
  - Example:
    ```motoko
    let reusedValues : Sighash.SighashReusedValues = { var previousOutputsHash = null; ... };
    switch (Sighash.calculate_sighash_ecdsa(tx, 0, utxo, Sighash.SigHashAll, reusedValues)) {
      case (?hash) { Sighash.hex_from_array(hash) }; // Hex-encoded sighash
      case (null) { /* Invalid input */ };
    };
    ```

- `hex_from_array(bytes : [Nat8]) : Text`

  - Converts a byte array to a lowercase hex string.
  - Example: `[0xa1, 0xb2]` → `"a1b2"`.

- `array_from_hex(hex : Text) : [Nat8]`

  - Converts a hex string (lowercase or uppercase) to a byte array.
  - Returns an empty array if the hex string is invalid.
  - Example: `"a1b2"` → `[0xa1, 0xb2]`.

- `nat16_to_bytes(n : Nat16) : [Nat8]`, `nat32_to_bytes(n : Nat32) : [Nat8]`, `nat64_to_le_bytes(n : Nat64) : [Nat8]`

  - Converts numbers to little-endian byte arrays for serialization.
  - Example: `nat32_to_bytes(256)` → `[0x00, 0x01, 0x00, 0x00]`.

- `transaction_signing_ecdsa_domain_hash() : [Nat8]`

  - Returns the SHA-256 hash of the ECDSA domain separator (`"TransactionSigningHashECDSA"`).
  - Example: Returns a 32-byte array.

- `blake2b_256(data : [Nat8], key : ?Text) : [Nat8]`

  - Computes a Blake2b-256 hash of the input data, optionally with a key.
  - Example: `blake2b_256([0xa1, 0xb2], ?"TransactionSigningHash")` → 32-byte hash.

- `zero_hash() : [Nat8]`
  - Returns a 32-byte zero-filled array for sighash calculations.
  - Example: Returns `[0, 0, ..., 0]`.

### `transaction.mo`

Provides functions for building and serializing Hoosat transactions, including utilities for signature encoding and hex conversions. It supports creating transactions with one input and one or two outputs (recipient and optional change).

#### Public Functions

- `build_transaction(utxo : Types.UTXO, recipient_script : Text, output_amount : Nat64, fee : Nat64, change_script : Text) : Types.HoosatTransaction`

  - Builds a transaction with one input (from a UTXO) and one or two outputs (recipient and optional change if the remaining amount is above the dust threshold of 1000 sompi).
  - Returns an empty transaction if the UTXO amount is insufficient.
  - Example:
    ```motoko
    let utxo : Types.UTXO = {
      transactionId = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6";
      index = 0;
      amount = 2000000;
      scriptVersion = 0;
      scriptPublicKey = "20a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3ac";
      address = "Hoosat:qypq...";
    };
    let tx = Transaction.build_transaction(utxo, "20d4e5f6a1b2c3...ac", 1000000, 1000, "20a1b2c3d4e5f6...ac");
    // Returns a transaction with one input and two outputs (recipient + change)
    ```

- `serialize_transaction(tx : Types.HoosatTransaction) : Text`

  - Serializes a transaction to JSON format compatible with the Hoosat REST API.
  - Example:
    ```motoko
    let json = Transaction.serialize_transaction(tx);
    // Returns: "{\"transaction\":{\"version\":0,\"inputs\":[...],\"outputs\":[...],...}}"
    ```

- `sign_schnorr(sighash : [Nat8], private_key : [Nat8]) : [Nat8]`

  - Placeholder for Schnorr signing (currently returns a dummy 64-byte signature).
  - Expects a 32-byte sighash and 32-byte private key.
  - TODO: Implement actual Schnorr signing with a secp256k1 library or external canister.
  - Example:
    ```motoko
    let sighash = Sighash.array_from_hex("a1b2c3...");
    let privKey = Transaction.array_from_hex("d4e5f6...");
    let sig = Transaction.sign_schnorr(sighash, privKey); // Placeholder
    ```

- `signature_to_hex(sig : [Nat8]) : Text`

  - Converts a signature (e.g., DER-encoded) to a lowercase hex string.
  - Example: `[0xa1, 0xb2]` → `"a1b2"`.

- `array_from_hex(hex : Text) : [Nat8]`
  - Converts a hex string (lowercase or uppercase) to a byte array.
  - Returns an empty array if the hex string is invalid.
  - Example: `"a1b2"` → `[0xa1, 0xb2]`.

### `types.mo`

Defines data structures for Hoosat transactions and UTXOs, used across the other modules for address handling, sighash calculation, and transaction building.

#### Public Types

- `Outpoint`:

  ```motoko
  {
    transactionId: Text; // Hex-encoded transaction ID (64 chars)
    index: Nat32;       // Output index in the transaction
  }
  ```

  - Represents a transaction outpoint (reference to a previous output).

- `TransactionInput`:

  ```motoko
  {
    previousOutpoint: Outpoint; // Reference to the UTXO being spent
    signatureScript: Text;      // Hex-encoded signature script (empty before signing)
    sequence: Nat64;           // Sequence number for lock time or replacement
    sigOpCount: Nat8;          // Number of signature operations
  }
  ```

  - Represents an input in a Hoosat transaction.

- `ScriptPublicKey`:

  ```motoko
  {
    version: Nat16;          // Script version (e.g., 0)
    scriptPublicKey: Text;   // Hex-encoded script public key (e.g., "20<32-byte-pubkey>ac")
  }
  ```

  - Represents a script public key for an output.

- `TransactionOutput`:

  ```motoko
  {
    amount: Nat64;            // Amount in sompi
    scriptPublicKey: ScriptPublicKey; // Output script
  }
  ```

  - Represents an output in a Hoosat transaction.

- `HoosatTransaction`:

  ```motoko
  {
    version: Nat16;          // Transaction version (e.g., 0)
    inputs: [TransactionInput]; // Array of inputs
    outputs: [TransactionOutput]; // Array of outputs
    lockTime: Nat64;         // Lock time for transaction
    subnetworkId: Text;      // Hex-encoded subnetwork ID (40 chars)
    gas: Nat64;              // Gas for subnetwork transactions
    payload: Text;           // Hex-encoded payload
  }
  ```

  - Represents a complete Hoosat transaction.

- `UTXO`:
  ```motoko
  {
    transactionId: Text;     // Hex-encoded transaction ID (64 chars)
    index: Nat32;           // Output index
    amount: Nat64;          // Amount in sompi
    scriptVersion: Nat16;   // Script version (e.g., 0)
    scriptPublicKey: Text;  // Hex-encoded script public key
    address: Text;          // Hoosat address (e.g., "Hoosat:qypq...")
  }
  ```
  - Represents an unspent transaction output.

#### Example

```motoko
let tx : Types.HoosatTransaction = {
  version = 0;
  inputs = [{
    previousOutpoint = { transactionId = "a1b2c3d4e5f6..."; index = 0 };
    signatureScript = "";
    sequence = 0;
    sigOpCount = 1;
  }];
  outputs = [{
    amount = 1000000;
    scriptPublicKey = { version = 0; scriptPublicKey = "20d4e5f6...ac" };
  }];
  lockTime = 0;
  subnetworkId = "0000000000000000000000000000000000000000";
  gas = 0;
  payload = "";
};
```

## Contributing

Contributions are welcome! Please open an issue or pull request on the [GitHub repository](https://github.com/codecustard/Hoosat-mo).

## License

[MIT License](LICENSE)

## Additional Resources

- [Quick Start](https://internetcomputer.org/docs/current/developer-docs/setup/deploy-locally)
- [SDK Developer Tools](https://internetcomputer.org/docs/current/developer-docs/setup/install)
- [Motoko Programming Language Guide](https://internetcomputer.org/docs/current/motoko/main/motoko)
- [Motoko Language Quick Reference](https://internetcomputer.org/docs/current/motoko/main/language-manual)
