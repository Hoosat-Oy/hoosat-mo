import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Nat "mo:base/Nat";
import Text "mo:base/Text";

import IC "ic:aaaaa-aa";

import Address "../kaspa/address";
import Transaction "../kaspa/transaction";
import Types "../kaspa/types";
import Sighash "../kaspa/sighash";


persistent actor {
    private let key_id = "dfx_test_key";

    private func sign_digest(digest: [Nat8]) : async ?[Nat8] {
        try {
            Cycles.add<system>(30_000_000_000);
            let sig = await IC.sign_with_ecdsa({
                message_hash = Blob.fromArray(digest);
                derivation_path = [];
                key_id = { curve = #secp256k1; name = key_id };
            });
            ?Blob.toArray(sig.signature)
        } catch (e) {
            Debug.print("ECDSA signing failed: " # Error.message(e));
            null
        }
    };

    private func get_ecdsa_pubkey() : async ?Blob {
        try {
            let pk = await IC.ecdsa_public_key({
                canister_id = null;
                derivation_path = [];
                key_id = { curve = #secp256k1; name = key_id };
            });
            ?pk.public_key
        } catch (e) {
            Debug.print("ECDSA fetch failed: " # Error.message(e));
            null
        }
    };

    public func get_kaspa_address() : async Text {
        let maybe_pk = await get_ecdsa_pubkey();
        switch (maybe_pk) {
            case (null) {
                Debug.print("🚨 Failed to fetch ECDSA public key");
                "";
            };
            case (?pk) {
                switch (Address.address_from_pubkey(pk, Address.ECDSA)) {
                    case ("") {
                        Debug.print("🚨 Failed to generate Kaspa address");
                        "";
                    };
                    case (addr) { addr };
                }
            };
        }
    };

    public func send_kas(
        recipient_address: Text,
        amount: Nat64
    ) : async ?Text {
        // --- 1️⃣ Decode recipient address ---
        let decoded = Address.decode_address(recipient_address);

        switch (decoded) {
            case (null) {
                Debug.print("🚨 Invalid recipient address");
                return null;
            };
            case (? (addr_type, pubkey)) {
                // --- Convert pubkey to hex for nicer printing ---
                let pubkey_hex = Address.hex_from_array(pubkey);
                Debug.print("Recipient decoded address: type=" # Nat.toText(addr_type) # ", pubkey=" # pubkey_hex);

                // --- 2️⃣ Convert to scriptPublicKey ---
                let recipient_script = Address.pubkey_to_script(pubkey, addr_type);
                if (recipient_script == "") {
                    Debug.print("🚨 Failed to generate recipient scriptPublicKey");
                    return null;
                };
                Debug.print("Recipient scriptPublicKey: " # recipient_script);
                // return ?recipient_script;

                // --- Fetch UTXO (hardcoded for now) ---
                let utxo: Types.UTXO = {
                    transactionId = "75b23c8a72ed66a1a9b0111a609b20314a9fe873785ab931cec1b3846e0eeafd";
                    index = 1;
                    amount = 400_000_000;
                    scriptPublicKey = "210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab";
                    scriptVersion = 0;
                    address = "kaspa:qypff6urmgk8452vjx55r63dhc38s6ewlavknmnefzgac42n3lt8cdchp86su6n";
                };

                // --- Build transaction ---
                let tx: Types.KaspaTransaction = Transaction.build_transaction(
                    utxo,
                    recipient_script,
                    amount,
                    10_000  // fee
                );

                // --- Prepare reused values for sighash ---
                var reused: Sighash.SighashReusedValues = {
                    var previousOutputsHash = null;
                    var sequencesHash = null;
                    var sigOpCountsHash = null;
                    var outputsHash = null;
                    var payloadHash = null;
                };

                // --- Calculate digest ---
                var sighash_digest: ?[Nat8] = null;
                if (addr_type == Address.ECDSA) {
                    sighash_digest := Sighash.calculate_sighash_ecdsa(tx, 0, utxo, Sighash.SigHashAll, reused);
                } else {
                    Debug.print("Unsupported addr_type for signing");
                    return null;
                };

                // --- Unwrap digest safely ---
                let digest: [Nat8] = switch (sighash_digest) {
                    case (null) {
                        Debug.print("🚨 Failed to calculate sighash");
                        return null;
                    };
                    case (?d) { d };
                };

                // --- Print the digest ---
                let digest_hex = Address.hex_from_array(digest);
                Debug.print("Sighash digest (hex): " # digest_hex);

                // --- Sign digest ---
                let signature_opt: ?[Nat8] = await sign_digest(digest);

                // --- Unwrap signature safely ---
                let signature: [Nat8] = switch (signature_opt) {
                    case (null) {
                        Debug.print("🚨 Signing failed");
                        return null;
                    };
                    case (?s) { s };
                };

                // Convert signature to hex
                let sig_hex = Address.hex_from_array(signature);
                Debug.print("Signature (hex): " # sig_hex);

                // --- Build signatureScript ---
                let signature_script = Buffer.Buffer<Nat8>(0);
                signature_script.add(65); // OP_DATA_65 (length of 64-byte signature + 1-byte hashType)
                signature_script.append(Buffer.fromArray(signature));
                signature_script.add(Sighash.SigHashAll); // Append hashType (0x01)

                // --- Update transaction input with signatureScript ---
                let updated_inputs = Array.mapEntries(tx.inputs, func (input: Types.TransactionInput, i: Nat) : Types.TransactionInput {
                    if (i == 0) {
                        { input with signatureScript = Address.hex_from_array(Buffer.toArray(signature_script)) }
                    } else {
                        input
                    }
                });

                let signed_tx: Types.KaspaTransaction = {
                    tx with inputs = updated_inputs
                };

                // --- Serialize signed transaction ---
                let serialized_tx = Transaction.serialize_transaction(signed_tx);
                Debug.print("Serialized signed transaction: " # serialized_tx);
                return ?serialized_tx;
            };
        };
    };

};