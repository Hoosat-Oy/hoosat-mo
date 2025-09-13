import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Char "mo:base/Char";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
import Error "mo:base/Error";
import Iter "mo:base/Iter";

import Address "address";
import Sighash "sighash";
import Types "types";

module {
    // Key ID for threshold ECDSA (configure as needed)
    private let key_id = "dfx_test_key";

    // secp256k1 curve order / 2 for low-S normalization
    private let curve_n_half : [Nat8] = [
        0x7F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0x5D, 0x57, 0x6E, 0x73, 0x57, 0xA4, 0x50, 0x1D,
        0xDF, 0xE9, 0x2F, 0x46, 0x68, 0x1B, 0x20, 0xA0
    ];

    // Fetch ECDSA public key from IC
    // public func get_ecdsa_pubkey(derivation_path : [Blob]) : async ?[Nat8] {
    //     try {
    //         let pubkey = await IC.ecdsa_public_key({
    //             canister_id = null;
    //             derivation_path = derivation_path;
    //             key_id = { curve = #secp256k1; name = key_id };
    //         });
    //         let pubkey_bytes = Blob.toArray(pubkey.public_key);
    //         if (pubkey_bytes.size() != 33) {
    //             Debug.print("Invalid pubkey length: " # Nat.toText(pubkey_bytes.size()) # ", expected 33 bytes");
    //             return null;
    //         };
    //         ?pubkey_bytes
    //     } catch (e) {
    //         Debug.print("Error fetching ECDSA public key: " # Error.message(e));
    //         return null;
    //     }
    // };

    // Sign a transaction hash with ECDSA
    /*
    public func sign_ecdsa(tx_hash : [Nat8], derivation_path : [Blob]) : async ?[Nat8] {
        if (tx_hash.size() != 32) {
            Debug.print("Invalid transaction hash length: " # Nat.toText(tx_hash.size()) # ", expected 32 bytes");
            return null;
        };
        try {
            let signature = await IC.sign_with_ecdsa({
                message_hash = Blob.fromArray(tx_hash);
                derivation_path = derivation_path;
                key_id = { curve = #secp256k1; name = key_id };
            });
            let signature_bytes = Blob.toArray(signature.signature);
            if (signature_bytes.size() != 64) {
                Debug.print("Invalid signature length: " # Nat.toText(signature_bytes.size()) # ", expected 64 bytes");
                return null;
            };

            // Convert to DER format with low-S normalization
            // let der = encode_der_signature(signature_bytes);
            // if (der.size() == 0) {
            //     Debug.print("Failed to encode DER signature");
            //     return null;
            // };
            // ?der
            ?signature_bytes
        } catch (e) {
            Debug.print("Error signing with ECDSA: " # Error.message(e));
            return null;
        }
    };
    */

    // Helper to encode (r,s) signature to DER format for Kaspa with low-S normalization
    private func encode_der_signature(sig : [Nat8]) : [Nat8] {
        if (sig.size() != 64) {
            Debug.print("Invalid signature length: " # Nat.toText(sig.size()) # ", expected 64 bytes");
            return [];
        };
        let r = Array.subArray(sig, 0, 32);
        let s = Array.subArray(sig, 32, 32);
        // Normalize s to low-S (s <= n/2)
        let s_normalized = if (compare_bytes(s, curve_n_half) > 0) {
            subtract_bytes(curve_n_half, s)
        } else {
            s
        };
        // Add leading zeros if high bit is set
        let r_prefix = if (r[0] >= 0x80) { [0x00 : Nat8] } else { [] };
        let s_prefix = if (s_normalized[0] >= 0x80) { [0x00 : Nat8] } else { [] };
        let r_der = Array.append([0x02 : Nat8, Nat8.fromNat(r_prefix.size() + r.size())], Array.append(r_prefix, r));
        let s_der = Array.append([0x02 : Nat8, Nat8.fromNat(s_prefix.size() + s_normalized.size())], Array.append(s_prefix, s_normalized));
        let seq = Array.append(r_der, s_der);
        Array.append([0x30 : Nat8, Nat8.fromNat(seq.size())], seq)
    };

    // Compare two 32-byte arrays (returns 1 if a > b, 0 if equal, -1 if a < b)
    private func compare_bytes(a : [Nat8], b : [Nat8]) : Int {
        if (a.size() != b.size()) {
            Debug.print("Cannot compare arrays of different lengths");
            return 0;
        };
        for (i in Iter.range(0, a.size() - 1)) {
            if (a[i] > b[i]) return 1;
            if (a[i] < b[i]) return -1;
        };
        0
    };

    // Subtract b from a (a - b) for 32-byte arrays (for low-S normalization)
    private func subtract_bytes(a : [Nat8], b : [Nat8]) : [Nat8] {
        if (a.size() != 32 or b.size() != 32) {
            Debug.print("Invalid array lengths for subtraction: a=" # Nat.toText(a.size()) # ", b=" # Nat.toText(b.size()));
            return [];
        };
        let result = Buffer.Buffer<Nat8>(32);
        var borrow : Nat = 0;
        for (i in Iter.range(0, 31)) {
            let ai = Nat8.toNat(a[31 - i]);
            let bi = Nat8.toNat(b[31 - i]);
            let diff = ai - bi - borrow;
            if (diff < 0) {
                result.add(Nat8.fromNat(diff + 256));
                borrow := 1;
            } else {
                result.add(Nat8.fromNat(diff));
                borrow := 0;
            };
        };
        Array.reverse(Buffer.toArray(result))
    };

    // Convert DER signature to hex for testing
    public func signature_to_hex(sig : [Nat8]) : Text {
        Address.hex_from_array(sig)
    };

    // Helper to convert hex to bytes
    public func array_from_hex(hex: Text) : [Nat8] {
        let chars = Text.toIter(hex);
        let result = Buffer.Buffer<Nat8>(hex.size() / 2);
        var byte: Nat = 0;
        var is_high = true;
        for (c in chars) {
            let val = if (c >= '0' and c <= '9') {
                Nat32.toNat(Char.toNat32(c) - Char.toNat32('0'))
            } else if (c >= 'a' and c <= 'f') {
                Nat32.toNat(Char.toNat32(c) - Char.toNat32('a') + 10)
            } else if (c >= 'A' and c <= 'F') {
                Nat32.toNat(Char.toNat32(c) - Char.toNat32('A') + 10)
            } else {
                return [];
            };
            if (is_high) {
                byte := val * 16;
                is_high := false;
            } else {
                byte += val;
                result.add(Nat8.fromNat(byte));
                is_high := true;
            }
        };
        Buffer.toArray(result)
    };

    // Placeholder for Schnorr signing
    public func sign_schnorr(sighash: [Nat8], private_key: [Nat8]) : [Nat8] {
        // TODO: Implement Schnorr signing (e.g., using secp256k1 library or external canister)
        // Input: 32-byte sighash, 32-byte private key
        // Output: 64-byte Schnorr signature
        let dummy_signature : [Nat8] = Array.freeze(Array.init<Nat8>(64, 0));
        dummy_signature
    };

    // Build a transaction with one input and one output
    public func build_transaction(
        utxo: Types.UTXO,
        recipient_script: Text, // scriptPublicKey of recipient (hex)
        output_amount: Nat64,  // Amount to send (in sompi)
        fee: Nat64             // Transaction fee (in sompi)
    ) : Types.KaspaTransaction {
        let total_input = utxo.amount;
        if (total_input < output_amount + fee) {
            Debug.print("🚨 Insufficient UTXO amount for transaction");
            return {
                version = 0;
                inputs = [];
                outputs = [];
                lockTime = 0;
                subnetworkId = "0000000000000000000000000000000000000000";
                gas = 0;
                payload = "";
            };
        };

        {
            version = 0;
            inputs = [
                {
                    previousOutpoint = {
                        transactionId = utxo.transactionId;
                        index = utxo.index;
                    };
                    signatureScript = ""; // To be set after signing
                    sequence = 0;
                    sigOpCount = 1;
                }
            ];
            outputs = [
                {
                    amount = output_amount;
                    scriptPublicKey = {
                        version = 0;
                        scriptPublicKey = recipient_script;
                    };
                }
            ];
            lockTime = 0;
            subnetworkId = "0000000000000000000000000000000000000000";
            gas = 0;
            payload = "";
        }
    };

    // Sign a transaction input (supports both Schnorr and ECDSA)
    /*
    public func sign_transaction(
        tx: Types.KaspaTransaction,
        input_index: Nat,
        utxo: Types.UTXO,
        derivation_path: [Blob], // Used for ECDSA
        private_key: ?[Nat8],   // Used for Schnorr, null for ECDSA
        hashType: Sighash.SigHashType,
        addr_type: Nat          // Address.SCHNORR or Address.ECDSA
    ) : async ?Types.KaspaTransaction {
        let reusedValues: Sighash.SighashReusedValues = {
            var previousOutputsHash = null;
            var sequencesHash = null;
            var sigOpCountsHash = null;
            var outputsHash = null;
            var payloadHash = null;
        };

        switch (Sighash.calculate_sighash_schnorr(tx, input_index, utxo, hashType, reusedValues)) {
            case (null) {
                Debug.print("🚨 Failed to compute sighash for input " # Nat.toText(input_index));
                return null;
            };
            case (?sighash) {
                Debug.print("Sighash: " # Sighash.hex_from_array(sighash));

                // Generate signature based on address type
                let signature_script = Buffer.Buffer<Nat8>(0);
                if (addr_type == Address.SCHNORR) {
                    switch (private_key) {
                        case (null) {
                            Debug.print("🚨 Schnorr signing requires private key");
                            return null;
                        };
                        case (?priv_key) {
                            let signature = sign_schnorr(sighash, priv_key);
                            signature_script.add(65); // OP_DATA_65
                            signature_script.append(Buffer.fromArray(signature));
                            signature_script.add(hashType);
                        };
                    };
                } else if (addr_type == Address.ECDSA) {
                    switch (await sign_ecdsa(sighash, derivation_path)) {
                        case (null) {
                            Debug.print("🚨 ECDSA signing failed");
                            return null;
                        };
                        case (?der_sig) {
                            signature_script.add(Nat8.fromNat(der_sig.size() + 1)); // OP_DATA_<len>
                            signature_script.append(Buffer.fromArray(der_sig));
                            signature_script.add(hashType);
                        };
                    };
                } else {
                    Debug.print("🚨 Unsupported address type: " # Nat.toText(addr_type));
                    return null;
                };

                // Update transaction input
                let updated_inputs = Array.mapEntries(tx.inputs, func (input: Types.TransactionInput, i: Nat) : Types.TransactionInput {
                    if (i == input_index) {
                        { input with signatureScript = Address.hex_from_array(Buffer.toArray(signature_script)) }
                    } else {
                        input
                    }
                });

                let signed_tx: Types.KaspaTransaction = {
                    tx with inputs = updated_inputs
                };
                ?signed_tx
            };
        };
    };
    */

    // Serialize transaction to JSON for Kaspa REST API
    public func serialize_transaction(tx: Types.KaspaTransaction) : Text {
        let inputs_json = Array.foldLeft<Types.TransactionInput, Text>(
            tx.inputs,
            "[",
            func (acc: Text, input: Types.TransactionInput) : Text {
                acc # (if (acc != "[") { "," } else { "" }) #
                "{\"previousOutpoint\":{\"transactionId\":\"" # input.previousOutpoint.transactionId #
                "\",\"index\":" # Nat.toText(Nat32.toNat(input.previousOutpoint.index)) #
                "},\"signatureScript\":\"" # input.signatureScript #
                "\",\"sequence\":" # Nat64.toText(input.sequence) #
                ",\"sigOpCount\":" # Nat.toText(Nat8.toNat(input.sigOpCount)) # "}"
            }
        ) # "]";

        let outputs_json = Array.foldLeft<Types.TransactionOutput, Text>(
            tx.outputs,
            "[",
            func (acc: Text, output: Types.TransactionOutput) : Text {
                acc # (if (acc != "[") { "," } else { "" }) #
                "{\"amount\":" # Nat64.toText(output.amount) #
                ",\"scriptPublicKey\":\"" # output.scriptPublicKey.scriptPublicKey # "\"}"
            }
        ) # "]";

        "{\"transaction\":{" #
        "\"version\":" # Nat.toText(Nat16.toNat(tx.version)) # "," #
        "\"inputs\":" # inputs_json # "," #
        "\"outputs\":" # outputs_json # "," #
        "\"lockTime\":" # Nat64.toText(tx.lockTime) # "," #
        "\"subnetworkId\":\"" # tx.subnetworkId # "\"," #
        "\"gas\":" # Nat64.toText(tx.gas) # "," #
        "\"payload\":\"" # tx.payload # "\"" #
        "}}"
    };

    // Transform function to strip headers for consensus
    /*
    public query func transform({ context : Blob; response : IC.http_request_result }) : async IC.http_request_result {
        {
            response with headers = []; // Remove headers for consensus
        }
    };
    */

    // Submit transaction to Kaspa testnet
    /*
    public func submit_transaction(serialized_tx: Text) : async ?Text {
        let host = "api.testnet.kaspa.org";
        let url = "https://" # host # "/transactions/submit";
        let request_headers = [
            { name = "Content-Type"; value = "application/json" },
            { name = "User-Agent"; value = "kaspa-transaction-canister" }
        ];

        let http_request : IC.http_request_args = {
            url = url;
            max_response_bytes = ?2048;
            headers = request_headers;
            body = ?Text.encodeUtf8(serialized_tx);
            method = #post;
            transform = ?{
                function = transform;
                context = Blob.fromArray([]);
            };
        };

        Cycles.add<system>(230_949_972_000);

        let response = await IC.http_request(http_request);

        switch (response.status) {
            case (200) {
                let decoded_text = switch (Text.decodeUtf8(response.body)) {
                    case (null) { "No value returned" };
                    case (?text) { text };
                };
                Debug.print("✅ Transaction submitted: " # decoded_text);
                ?decoded_text
            };
            case (_) {
                let decoded_text = switch (Text.decodeUtf8(response.body)) {
                    case (null) { "No value returned" };
                    case (?text) { text };
                };
                Debug.print("🚨 Submission failed: Status " # Nat.toText(response.status) # ", Body: " # decoded_text);
                null
            };
        };
    };
    */

    // Build and sign a transaction, return JSON for manual submission
    /*
    public func build_sign_transaction(
        utxo: Types.UTXO,
        recipient_script: Text,
        output_amount: Nat64,
        fee: Nat64,
        derivation_path: [Blob], // Used for ECDSA
        private_key: ?[Nat8],   // Used for Schnorr, null for ECDSA
        addr_type: Nat          // Address.SCHNORR or Address.ECDSA
    ) : async ?Text {
        // Build transaction
        let tx = build_transaction(utxo, recipient_script, output_amount, fee);
        if (tx.inputs.size() == 0) {
            Debug.print("🚨 Transaction build failed");
            return null;
        };

        // Sign transaction
        switch (await sign_transaction(tx, 0, utxo, derivation_path, private_key, Sighash.SigHashAll, addr_type)) {
            case (null) {
                Debug.print("🚨 Transaction signing failed");
                return null;
            };
            case (?signed_tx) {
                // Serialize transaction to JSON
                let serialized_tx = serialize_transaction(signed_tx);
                Debug.print("Serialized transaction: " # serialized_tx);
                ?serialized_tx
            };
        };
    };
    */

    // Main function to build, sign, and submit a transaction
    /*
    public func build_sign_submit_transaction(
        utxo: Types.UTXO,
        recipient_script: Text,
        output_amount: Nat64,
        fee: Nat64,
        derivation_path: [Blob],
        private_key: ?[Nat8],
        addr_type: Nat
    ) : async ?Text {
        // Build transaction
        let tx = build_transaction(utxo, recipient_script, output_amount, fee);
        if (tx.inputs.size() == 0) {
            Debug.print("🚨 Transaction build failed");
            return null;
        };

        // Sign transaction
        switch (await sign_transaction(tx, 0, utxo, derivation_path, private_key, Sighash.SigHashAll, addr_type)) {
            case (null) {
                Debug.print("🚨 Transaction signing failed");
                return null;
            };
            case (?signed_tx) {
                // Serialize transaction
                let serialized_tx = serialize_transaction(signed_tx);
                Debug.print("Serialized transaction: " # serialized_tx);

                // Submit transaction
                return await submit_transaction(serialized_tx);
            };
        };
    };
    */
};