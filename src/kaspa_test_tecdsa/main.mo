// import Buffer "mo:base/Buffer";
// import Blob "mo:base/Blob";
// import Cycles "mo:base/ExperimentalCycles";
// import Error "mo:base/Error";
// import Iter "mo:base/Iter";
// import Nat64 "mo:base/Nat64";
// import Nat16 "mo:base/Nat16";
// import Nat32 "mo:base/Nat32";
// import Nat8 "mo:base/Nat8";
// import Principal "mo:base/Principal";
// import Text "mo:base/Text";
// import Array "mo:base/Array";


// import Address "../kaspa/address";
// import Sighash "../kaspa/sighash";
// import Types "../kaspa/types";


// persistent actor {

//     // Management canister interface
//     type ManagementCanister = actor {
//         ecdsa_public_key : ({
//             canister_id : ?Principal;
//             derivation_path : [Blob];
//             key_id : { curve : { #secp256k1 }; name : Text };
//         }) -> async ({ public_key : Blob });
//         sign_with_ecdsa : ({
//             message_hash : Blob;
//             derivation_path : [Blob];
//             key_id : { curve : { #secp256k1 }; name : Text };
//         }) -> async ({ signature : Blob });
//     };

//     let management_canister : ManagementCanister = actor("aaaaa-aa");

//     // Your private key derivation path or key (for test; in production, use canister key)
//     let derivation_path: [Blob] = [Blob.fromArray([0])]; // Example

//     // Function to build, sign, serialize, and submit tx
//     public func test_spend_kaspa() : async Text {
//         let utxo: Types.UTXO = {
//             transactionId = "75b23c8a72ed66a1a9b0111a609b20314a9fe873785ab931cec1b3846e0eeafd";
//             index = 1;
//             amount = 400_000_000;
//             scriptPublicKey = "210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab";
//             scriptVersion = 0;
//             address = "kaspa:qypff6urmgk8452vjx55r63dhc38s6ewlavknmnefzgac42n3lt8cdchp86su6n";
//         };

//         let new_address = "kaspa:qr9fqcxp9xjprsm9sv7apy6qc0ja2p676m9gf9fkcww2qmaw4npxzllh7lrw0"; // Replace with your new address
//         let (addr_type, payload_bytes) = switch (Address.decode_address(new_address)) {
//             case (null) { throw Error.reject("Invalid address"); };
//             case (?res) res;
//         };
//         let script_pubkey_hex = Sighash.hex_from_array(Array.append<Nat8>([Nat8.fromNat(payload_bytes.size())], payload_bytes)) # "ab"; // For ECDSA P2PK

//         let tx: Types.KaspaTransaction = {
//             version = 0;
//             inputs = [{
//                 previousOutpoint = { transactionId = utxo.transactionId; index = utxo.index };
//                 signatureScript = "";
//                 sequence = 0;
//                 sigOpCount = 1;
//             }];
//             outputs = [{
//                 amount = utxo.amount - 10_000; // Deduct fee
//                 scriptPublicKey = {
//                     version = 0;
//                     scriptPublicKey = script_pubkey_hex;
//                 };
//             }];
//             lockTime = 0;
//             subnetworkId = "0000000000000000000000000000000000000000";
//             gas = 0;
//             payload = "";
//         };

//         let reusedValues: Sighash.SighashReusedValues = {
//             var previousOutputsHash = null;
//             var sequencesHash = null;
//             var sigOpCountsHash = null;
//             var outputsHash = null;
//             var payloadHash = null;
//         };

//         let hashType = Sighash.SigHashAll; // Standard
//         let sighash_opt = Sighash.calculate_sighash_ecdsa(tx, 0, utxo, hashType, reusedValues);
//         let sighash = switch (sighash_opt) {
//             case (null) { throw Error.reject("Sighash calculation failed"); };
//             case (?h) Blob.fromArray(h);
//         };

        

//         // Sign with ICP ECDSA (assume canister has key; adjust curve/args as needed for secp256k1)
//         Cycles.add<system>(30_000_000_000);
//         let signature = await management_canister.sign_with_ecdsa({
//             message_hash = sighash;
//             derivation_path = []; // Use empty derivation path
//             key_id = { curve = #secp256k1; name = "dfx_test_key" };
//         });

//         // Format signatureScript: "41" + DER signature + "01" (for ECDSA in Kaspa)
//         let sig_der_hex = Sighash.hex_from_array(Blob.toArray(signature));
//         let signature_script = "41" # sig_der_hex # "01"; // Length-prefixed DER + SIGHASH_ALL

//         // Update tx with signature
//         let updated_inputs = Array.map(tx.inputs, func (inp: Types.TransactionInput) : Types.TransactionInput {
//             if (inp.previousOutpoint.index == utxo.index) {
//                 { inp with signatureScript = signature_script };
//             } else inp;
//         });
//         let signed_tx = { tx with inputs = updated_inputs };

//         // Serialize the signed tx (implement serialization based on Kaspa format)
//         let serialized_tx = serialize_transaction(signed_tx); // See below for implementation

//         // Submit to Kaspa node via HTTP (use ICP HTTP outcalls)
//         let node_url = "https://api.kaspa.org"; // Or your node/testnet
//         let response = await submit_transaction(node_url, serialized_tx);
//         response // Return tx ID or error
//     };

//     // Helper: Serialize KaspaTransaction to hex for submission
//     private func serialize_transaction(tx: Types.KaspaTransaction) : Text {
//         let buf = Buffer.Buffer<Nat8>(0);

//         // Version (2 LE)
//         buf.append(Buffer.fromArray(Sighash.nat16_to_bytes(tx.version)));

//         // Inputs length (varint, assume compact size like Bitcoin)
//         buf.append(Buffer.fromArray(compact_size(tx.inputs.size())));

//         for (inp in tx.inputs.vals()) {
//             // Previous outpoint: txid (32) + index (4 LE)
//             buf.append(Buffer.fromArray(Sighash.hex_to_bytes(inp.previousOutpoint.transactionId)));
//             buf.append(Buffer.fromArray(Sighash.nat32_to_bytes(inp.previousOutpoint.index)));

//             // Signature script: length (compact) + script
//             let sig_bytes = Sighash.hex_to_bytes(inp.signatureScript);
//             buf.append(Buffer.fromArray(compact_size(sig_bytes.size())));
//             buf.append(Buffer.fromArray(sig_bytes));

//             // Sequence (8 LE)
//             buf.append(Buffer.fromArray(Sighash.nat64_to_le_bytes(inp.sequence)));
//         };

//         // Outputs length (compact)
//         buf.append(Buffer.fromArray(compact_size(tx.outputs.size())));

//         for (out in tx.outputs.vals()) {
//             // Amount (8 LE)
//             buf.append(Buffer.fromArray(Sighash.nat64_to_le_bytes(out.amount)));

//             // Script version (2 LE)
//             buf.append(Buffer.fromArray(Sighash.nat16_to_bytes(out.scriptPublicKey.version)));

//             // Script length (8 LE) + script
//             let script_bytes = Sighash.hex_to_bytes(out.scriptPublicKey.scriptPublicKey);
//             buf.append(Buffer.fromArray(Sighash.nat64_to_le_bytes(Nat64.fromNat(script_bytes.size()))));
//             buf.append(Buffer.fromArray(script_bytes));
//         };

//         // Lock time (8 LE)
//         buf.append(Buffer.fromArray(Sighash.nat64_to_le_bytes(tx.lockTime)));

//         // Subnetwork ID (20 bytes)
//         buf.append(Buffer.fromArray(Sighash.hex_to_bytes(tx.subnetworkId)));

//         // Gas (8 LE)
//         buf.append(Buffer.fromArray(Sighash.nat64_to_le_bytes(tx.gas)));

//         // Payload: length (compact) + payload
//         let payload_bytes = Sighash.hex_to_bytes(tx.payload);
//         buf.append(Buffer.fromArray(compact_size(payload_bytes.size())));
//         buf.append(Buffer.fromArray(payload_bytes));

//         Sighash.hex_from_array(Buffer.toArray(buf))
//     };

//     // Helper: Compact size (varint like Bitcoin)
//     private func compact_size(n: Nat) : [Nat8] {
//         if (n < 253) { [Nat8.fromNat(n)] } else if (n <= 0xFFFF) {
//             [0xFD, Nat8.fromNat(n & 0xFF), Nat8.fromNat((n >> 8) & 0xFF)];
//         } else if (n <= 0xFFFFFFFF) {
//             [0xFE, Nat8.fromNat(n & 0xFF), Nat8.fromNat((n >> 8) & 0xFF), Nat8.fromNat((n >> 16) & 0xFF), Nat8.fromNat((n >> 24) & 0xFF)];
//         } else {
//             [0xFF] # Sighash.nat64_to_le_bytes(Nat64.fromNat(n));
//         };
//     };

//     // Helper: Submit via HTTP outcall (implement with ic:HttpRequest)
//     private func submit_transaction(url: Text, tx_hex: Text) : async Text {
//         // Use ICP HTTP API to POST {"transaction": tx_hex} to url + "/transactions"
//         // Return response (tx ID) or error
//         "Implemented submission - tx ID or error"; // Placeholder
//     };

// };









import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Nat "mo:base/Nat";

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

                // --- Return signed transaction (hex) for now ---
                // let tx_json = Transaction.serialize_signed(tx, signature);
                // Debug.print("Signed transaction ready: " # tx_json);
                // ?tx_json
                return ?""
            };
        };
    };

    /*
    public func run_transaction() : async ?Text {
        // Sample UTXO (replace with real data from getUtxosByAddresses)
        let utxo: Types.UTXO = {
            transactionId = "11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff";
            index = 0;
            amount = 100000000; // 1 KAS
            scriptPublicKey = "20e9edf67a325868ecc7cd8519e6ca5265e65b7d10f56066461ceabf0c2bc1c5adac";
            scriptVersion = 0;
            address = "kaspatest:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqz";
        };

        // Recipient address (e.g., your own address or another testnet address)
        let recipient_address = "kaspatest:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqz";
        let decoded = switch (Address.decode_address(recipient_address)) {
            case (null) {
                Debug.print("🚨 Invalid recipient address");
                return null;
            };
            case (?(addr_type, pubkey)) { (addr_type, pubkey) };
        };
        let recipient_script = Address.pubkey_to_script(decoded.1, decoded.0);
        if (recipient_script == "") {
            Debug.print("🚨 Failed to generate scriptPublicKey");
            return null;
        };

        // Transaction parameters
        let output_amount = 99900000; // 0.999 KAS
        let fee = 10000; // 0.0001 KAS
        let private_key = Transaction.array_from_hex("your_private_key_hex"); // Replace with 32-byte private key

        // Build and sign transaction, get JSON
        switch (Transaction.build_sign_transaction(utxo, recipient_script, output_amount, fee, private_key)) {
            case (null) {
                Debug.print("🚨 Transaction failed");
                null
            };
            case (?json) {
                Debug.print("✅ Transaction JSON: " # json);
                ?json
            };
        };
    };
    */
};