import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Char "mo:base/Char";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import Debug "mo:base/Debug";

import Blake3 "mo:blake3";
import Sha256 "mo:sha2/Sha256";

import Types "../../src/types";

module SighashHoosat {

    // SigHashType definitions
    public type SigHashType = Nat8;
    public let SigHashAll: SigHashType = 0x01;
    public let SigHashNone: SigHashType = 0x02;
    public let SigHashSingle: SigHashType = 0x04;
    public let SigHashAnyOneCanPay: SigHashType = 0x80;
    public let SigHashMask: SigHashType = 0x07;
    public let SigHashAll_AnyOneCanPay: SigHashType = 0x81;
    public let SigHashNone_AnyOneCanPay: SigHashType = 0x82;
    public let SigHashSingle_AnyOneCanPay: SigHashType = 0x84;

    // Check if SigHashType is standard
    public func is_standard_sighash_type(hashType: SigHashType): Bool {
        hashType == SigHashAll or
        hashType == SigHashNone or
        hashType == SigHashSingle or
        hashType == SigHashAll_AnyOneCanPay or
        hashType == SigHashNone_AnyOneCanPay or
        hashType == SigHashSingle_AnyOneCanPay
    };

    // SighashReusedValues
    public type SighashReusedValues = {
        var previousOutputsHash: ?[Nat8];
        var sequencesHash: ?[Nat8];
        var sigOpCountsHash: ?[Nat8];
        var outputsHash: ?[Nat8];
        var payloadHash: ?[Nat8];
    };

    // Helper: Convert Nat16 to little-endian bytes
    public func nat16_to_bytes(n: Nat16): [Nat8] {
        [
            Nat8.fromNat(Nat16.toNat(n & 0xFF)),
            Nat8.fromNat(Nat16.toNat((n >> 8) & 0xFF))
        ]
    };

    // Helper: Convert Nat32 to little-endian bytes
    public func nat32_to_bytes(n: Nat32): [Nat8] {
        [
            Nat8.fromNat(Nat32.toNat(n & 0xFF)),
            Nat8.fromNat(Nat32.toNat((n >> 8) & 0xFF)),
            Nat8.fromNat(Nat32.toNat((n >> 16) & 0xFF)),
            Nat8.fromNat(Nat32.toNat((n >> 24) & 0xFF))
        ]
    };

    // Helper: Convert Nat64 to little-endian bytes
    public func nat64_to_le_bytes(n: Nat64): [Nat8] {
        [
            Nat8.fromNat(Nat64.toNat(n & 0xFF)),
            Nat8.fromNat(Nat64.toNat((n >> 8) & 0xFF)),
            Nat8.fromNat(Nat64.toNat((n >> 16) & 0xFF)),
            Nat8.fromNat(Nat64.toNat((n >> 24) & 0xFF)),
            Nat8.fromNat(Nat64.toNat((n >> 32) & 0xFF)),
            Nat8.fromNat(Nat64.toNat((n >> 40) & 0xFF)),
            Nat8.fromNat(Nat64.toNat((n >> 48) & 0xFF)),
            Nat8.fromNat(Nat64.toNat((n >> 56) & 0xFF))
        ]
    };

    // Helper: Convert hex string to bytes
    public func hex_to_bytes(hex: Text) : [Nat8] {
        let chars = Text.toIter(hex);
        let result = Buffer.Buffer<Nat8>(hex.size() / 2);
        var byte : Nat = 0;
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

    // Helper: Convert bytes to hex string
    public func hex_from_array(bytes: [Nat8]) : Text {
        let hex_chars : [Char] = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'];
        let result = Buffer.Buffer<Char>(bytes.size() * 2);
        for (b in bytes.vals()) {
            let high = Nat8.toNat(b / 16);
            let low = Nat8.toNat(b % 16);
            result.add(hex_chars[high]);
            result.add(hex_chars[low]);
        };
        Text.fromIter(result.vals())
    };

    // Zero hash
    public func zero_hash(): [Nat8] {
        Array.tabulate<Nat8>(32, func(_) = 0)
    };

    // Schnorr domain hash
    private func transaction_signing_schnorr_domain(): Text {
        "TransactionSigningHash"
    };

    // ECDSA domain hash
    public func transaction_signing_ecdsa_domain_hash(): [Nat8] {
        let domain = "TransactionSigningHashECDSA";
        let domain_bytes = Text.encodeUtf8(domain);
        Blob.toArray(Sha256.fromBlob(#sha256, domain_bytes))
    };

    // Blake3 hash function - matches fixed JavaScript FixedPadKey implementation
    public func blake3_256(data: [Nat8], key: ?Text): [Nat8] {
        // Create 32-byte array like JavaScript Uint8Array(32)
        var fixed_key = Array.tabulate<Nat8>(32, func(_) = 0);

        switch (key) {
            case (?k) {
                // Encode domain string into the fixed 32-byte array (like encodeInto)
                let key_bytes = Blob.toArray(Text.encodeUtf8(k));
                let copy_len = Nat.min(key_bytes.size(), 32);
                fixed_key := Array.tabulate<Nat8>(32, func(i) {
                    if (i < copy_len) key_bytes[i] else 0
                });
            };
            case null {
                // Already zero-filled
            };
        };

        Blob.toArray(Blake3.keyed_hash(Blob.fromArray(fixed_key), Blob.fromArray(data)))
    };

    // Get PreviousOutputsHash
    private func get_previous_outputs_hash(
        tx: Types.KaspaTransaction,
        hashType: SigHashType,
        reusedValues: SighashReusedValues
    ): [Nat8] {
        if (hashType & SigHashAnyOneCanPay == SigHashAnyOneCanPay) {
            return zero_hash();
        };
        switch (reusedValues.previousOutputsHash) {
            case (?hash) { hash };
            case null {
                let hashWriter = Buffer.Buffer<Nat8>(0);
                for (txIn in tx.inputs.vals()) {
                    let txid_bytes = hex_to_bytes(txIn.previousOutpoint.transactionId);
                    let index_bytes = nat32_to_bytes(txIn.previousOutpoint.index);
                    hashWriter.append(Buffer.fromArray(txid_bytes));
                    hashWriter.append(Buffer.fromArray(index_bytes));
                };
                let hash = blake3_256(Buffer.toArray(hashWriter), ?transaction_signing_schnorr_domain());
                Debug.print("🔍 PreviousOutputsHash (Blake3): " # hex_from_array(hash));
                reusedValues.previousOutputsHash := ?hash;
                hash
            };
        }
    };

    // Get SequencesHash
    private func get_sequences_hash(
        tx: Types.KaspaTransaction,
        hashType: SigHashType,
        reusedValues: SighashReusedValues
    ): [Nat8] {
        if (hashType & SigHashMask == SigHashSingle or
            hashType & SigHashMask == SigHashNone or
            hashType & SigHashAnyOneCanPay == SigHashAnyOneCanPay) {
            return zero_hash();
        };
        switch (reusedValues.sequencesHash) {
            case (?hash) { hash };
            case null {
                let hashWriter = Buffer.Buffer<Nat8>(0);
                for (txIn in tx.inputs.vals()) {
                    let sequence_bytes = nat64_to_le_bytes(txIn.sequence);
                    hashWriter.append(Buffer.fromArray(sequence_bytes));
                };
                let hash = blake3_256(Buffer.toArray(hashWriter), ?transaction_signing_schnorr_domain());
                reusedValues.sequencesHash := ?hash;
                hash
            };
        }
    };

    // Get SigOpCountsHash
    private func get_sigop_counts_hash(
        tx: Types.KaspaTransaction,
        hashType: SigHashType,
        reusedValues: SighashReusedValues
    ): [Nat8] {
        if (hashType & SigHashAnyOneCanPay == SigHashAnyOneCanPay) {
            return zero_hash();
        };
        switch (reusedValues.sigOpCountsHash) {
            case (?hash) { hash };
            case null {
                let hashWriter = Buffer.Buffer<Nat8>(0);
                for (txIn in tx.inputs.vals()) {
                    hashWriter.add(txIn.sigOpCount);
                };
                let hash = blake3_256(Buffer.toArray(hashWriter), ?transaction_signing_schnorr_domain());
                reusedValues.sigOpCountsHash := ?hash;
                hash
            };
        }
    };

    // Get OutputsHash
    private func get_outputs_hash(
        tx: Types.KaspaTransaction,
        inputIndex: Nat,
        hashType: SigHashType,
        reusedValues: SighashReusedValues
    ): [Nat8] {
        if (hashType & SigHashMask == SigHashNone) {
            return zero_hash();
        };
        if (hashType & SigHashMask == SigHashSingle) {
            if (inputIndex >= tx.outputs.size()) {
                return zero_hash();
            };
            let hashWriter = Buffer.Buffer<Nat8>(0);
            let output = tx.outputs[inputIndex];
            let amount_bytes = nat64_to_le_bytes(output.amount);
            let version_bytes = nat16_to_bytes(output.scriptPublicKey.version);
            let script_bytes = hex_to_bytes(output.scriptPublicKey.scriptPublicKey);
            let script_len_bytes = nat64_to_le_bytes(Nat64.fromNat(script_bytes.size()));
            hashWriter.append(Buffer.fromArray(amount_bytes));
            hashWriter.append(Buffer.fromArray(version_bytes));
            hashWriter.append(Buffer.fromArray(script_len_bytes));
            hashWriter.append(Buffer.fromArray(script_bytes));
            return blake3_256(Buffer.toArray(hashWriter), ?transaction_signing_schnorr_domain());
        };
        switch (reusedValues.outputsHash) {
            case (?hash) { hash };
            case null {
                let hashWriter = Buffer.Buffer<Nat8>(0);
                for (output in tx.outputs.vals()) {
                    let amount_bytes = nat64_to_le_bytes(output.amount);
                    let version_bytes = nat16_to_bytes(output.scriptPublicKey.version);
                    let script_bytes = hex_to_bytes(output.scriptPublicKey.scriptPublicKey);
                    let script_len_bytes = nat64_to_le_bytes(Nat64.fromNat(script_bytes.size()));
                    hashWriter.append(Buffer.fromArray(amount_bytes));
                    hashWriter.append(Buffer.fromArray(version_bytes));
                    hashWriter.append(Buffer.fromArray(script_len_bytes));
                    hashWriter.append(Buffer.fromArray(script_bytes));
                };
                let hash = blake3_256(Buffer.toArray(hashWriter), ?transaction_signing_schnorr_domain());
                reusedValues.outputsHash := ?hash;
                hash
            };
        }
    };

    // Get PayloadHash
    private func get_payload_hash(
        tx: Types.KaspaTransaction,
        reusedValues: SighashReusedValues
    ): [Nat8] {
        let native_subnetwork = "0000000000000000000000000000000000000000";
        if (tx.subnetworkId == native_subnetwork and tx.payload.size() == 0) {
            return zero_hash();
        };
        switch (reusedValues.payloadHash) {
            case (?hash) { hash };
            case null {
                let payload_bytes = hex_to_bytes(tx.payload);
                let hash = blake3_256(payload_bytes, ?transaction_signing_schnorr_domain());
                reusedValues.payloadHash := ?hash;
                hash
            };
        }
    };

    // Calculate sighash for Schnorr
    public func calculate_sighash_schnorr(
        tx: Types.KaspaTransaction,
        input_index: Nat,
        utxo: Types.UTXO,
        hashType: SigHashType,
        reusedValues: SighashReusedValues
    ): ?[Nat8] {
        if (not is_standard_sighash_type(hashType)) {
            return null;
        };

        let hashWriter = Buffer.Buffer<Nat8>(0);

        // Version
        let version_bytes = nat16_to_bytes(tx.version);
        hashWriter.append(Buffer.fromArray(version_bytes));

        // PreviousOutputsHash
        let previous_outputs_hash = get_previous_outputs_hash(tx, hashType, reusedValues);
        hashWriter.append(Buffer.fromArray(previous_outputs_hash));

        // SequencesHash
        let sequences_hash = get_sequences_hash(tx, hashType, reusedValues);
        hashWriter.append(Buffer.fromArray(sequences_hash));

        // SigOpCountsHash
        let sigop_counts_hash = get_sigop_counts_hash(tx, hashType, reusedValues);
        hashWriter.append(Buffer.fromArray(sigop_counts_hash));

        // Outpoint
        let txid_bytes = hex_to_bytes(tx.inputs[input_index].previousOutpoint.transactionId);
        let index_bytes = nat32_to_bytes(tx.inputs[input_index].previousOutpoint.index);
        hashWriter.append(Buffer.fromArray(txid_bytes));
        hashWriter.append(Buffer.fromArray(index_bytes));

        // Script details
        let script_version_bytes = nat16_to_bytes(utxo.scriptVersion);
        hashWriter.append(Buffer.fromArray(script_version_bytes));

        let script_bytes = hex_to_bytes(utxo.scriptPublicKey);
        let script_len_bytes = nat64_to_le_bytes(Nat64.fromNat(script_bytes.size()));
        hashWriter.append(Buffer.fromArray(script_len_bytes));
        hashWriter.append(Buffer.fromArray(script_bytes));

        // Amount
        let amount_bytes = nat64_to_le_bytes(utxo.amount);
        hashWriter.append(Buffer.fromArray(amount_bytes));

        // Sequence
        let sequence_bytes = nat64_to_le_bytes(tx.inputs[input_index].sequence);
        hashWriter.append(Buffer.fromArray(sequence_bytes));

        // SigOpCount
        let sigop_count = [tx.inputs[input_index].sigOpCount];
        hashWriter.append(Buffer.fromArray(sigop_count));

        // OutputsHash
        let outputs_hash = get_outputs_hash(tx, input_index, hashType, reusedValues);
        hashWriter.append(Buffer.fromArray(outputs_hash));

        // LockTime
        let locktime_bytes = nat64_to_le_bytes(tx.lockTime);
        hashWriter.append(Buffer.fromArray(locktime_bytes));

        // SubnetworkID
        let subnetwork_bytes = hex_to_bytes(tx.subnetworkId);
        hashWriter.append(Buffer.fromArray(subnetwork_bytes));

        // Gas
        let gas_bytes = nat64_to_le_bytes(tx.gas);
        hashWriter.append(Buffer.fromArray(gas_bytes));

        // PayloadHash
        let payload_hash = get_payload_hash(tx, reusedValues);
        hashWriter.append(Buffer.fromArray(payload_hash));

        // SighashType
        let sighash_type_bytes = [hashType];
        hashWriter.append(Buffer.fromArray(sighash_type_bytes));

        let preimage_bytes = Buffer.toArray(hashWriter);
        let schnorr_result = blake3_256(preimage_bytes, ?transaction_signing_schnorr_domain());
        Debug.print("🔍 Schnorr sighash result (Blake3): " # hex_from_array(schnorr_result));
        ?schnorr_result
    };

    // Calculate sighash for ECDSA
    public func calculate_sighash_ecdsa(
        tx: Types.KaspaTransaction,
        input_index: Nat,
        utxo: Types.UTXO,
        hashType: SigHashType,
        reusedValues: SighashReusedValues
    ): ?[Nat8] {
        switch (calculate_sighash_schnorr(tx, input_index, utxo, hashType, reusedValues)) {
            case (null) {
                null;
            };
            case (?schnorr_hash) {
                let domain_hash = transaction_signing_ecdsa_domain_hash();
                let hash_writer = Buffer.Buffer<Nat8>(0);
                hash_writer.append(Buffer.fromArray(domain_hash));
                hash_writer.append(Buffer.fromArray(schnorr_hash));
                let final_preimage = Buffer.toArray(hash_writer);
                ?Blob.toArray(Sha256.fromBlob(#sha256, Blob.fromArray(final_preimage)))
            };
        }
    };

}