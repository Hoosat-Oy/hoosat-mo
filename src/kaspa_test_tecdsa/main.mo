import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import Nat8 "mo:base/Nat8";
import Char "mo:base/Char";

import Json "mo:json";

import IC "ic:aaaaa-aa";

import Address "../kaspa/address";
import Transaction "../kaspa/transaction";
import Types "../kaspa/types";
import Sighash "../kaspa/sighash";

persistent actor {
    private let key_id = "dfx_test_key";
    private let DUST_THRESHOLD : Nat64 = 1_000; // Minimum output amount in sompi

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

    // Helper function to convert Text to Nat64
    private func textToNat64(text: Text) : ?Nat64 {
        let chars = Text.toIter(text);
        var num: Nat = 0;
        for (c in chars) {
            if (c < '0' or c > '9') {
                return null;
            };
            num := num * 10 + Nat32.toNat(Char.toNat32(c) - Char.toNat32('0'));
        };
        if (num > Nat64.toNat(Nat64.maximumValue)) {
            return null;
        };
        ?Nat64.fromNat(num)
    };

    // Fetch UTXOs for an address from Kaspa mainnet
    public func fetch_utxos(address: Text) : async ?[Types.UTXO] {
        let host = "api.kaspa.org";
        let url = "https://" # host # "/addresses/" # address # "/utxos";
        let request_headers = [
            { name = "Content-Type"; value = "application/json" },
            { name = "User-Agent"; value = "kaspa-transaction-canister" }
        ];

        let http_request : IC.http_request_args = {
            url = url;
            max_response_bytes = ?4096;
            headers = request_headers;
            body = null; // GET request, no body
            method = #get;
            is_replicated = ?false;
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
                    case (null) { return null };
                    case (?text) { text };
                };
                Debug.print("UTXO response: " # decoded_text);

                // Parse JSON response
                switch (Json.parse(decoded_text)) {
                    case (#err(e)) {
                        Debug.print("🚨 Failed to parse UTXO JSON: " # debug_show(e));
                        return null;
                    };
                    case (#ok(json)) {
                        switch (json) {
                            case (#array(utxos)) {
                                let result = Buffer.Buffer<Types.UTXO>(0);
                                for (utxo_json in utxos.vals()) {
                                    switch (utxo_json) {
                                        case (#object_(obj)) {
                                            var transactionId: Text = "";
                                            var index: Nat32 = 0;
                                            var amount: Nat64 = 0;
                                            var scriptPublicKey: Text = "";
                                            var scriptVersion: Nat16 = 0;
                                            var utxoAddress: Text = "";

                                            for ((key, value) in obj.vals()) {
                                                switch (key, value) {
                                                    case ("address", #string(addr)) {
                                                        utxoAddress := addr;
                                                    };
                                                    case ("outpoint", #object_(outpoint_obj)) {
                                                        for ((k, v) in outpoint_obj.vals()) {
                                                            switch (k, v) {
                                                                case ("transactionId", #string(txid)) {
                                                                    transactionId := txid;
                                                                };
                                                                case ("index", #number(#int(n))) {
                                                                    index := Nat32.fromNat(Int.abs(n));
                                                                };
                                                                case _ {};
                                                            };
                                                        };
                                                    };
                                                    case ("utxoEntry", #object_(entry_obj)) {
                                                        for ((k, v) in entry_obj.vals()) {
                                                            switch (k, v) {
                                                                case ("amount", #string(amount_str)) {
                                                                    switch (textToNat64(amount_str)) {
                                                                        case (?n) { amount := n };
                                                                        case (null) {
                                                                            Debug.print("🚨 Failed to parse amount: " # amount_str);
                                                                            return null;
                                                                        };
                                                                    };
                                                                };
                                                                case ("scriptPublicKey", #object_(script_obj)) {
                                                                    for ((sk, sv) in script_obj.vals()) {
                                                                        switch (sk, sv) {
                                                                            case ("scriptPublicKey", #string(script)) {
                                                                                scriptPublicKey := script;
                                                                            };
                                                                            case _ {};
                                                                        };
                                                                    };
                                                                };
                                                                case _ {};
                                                            };
                                                        };
                                                    };
                                                    case _ {};
                                                };
                                            };

                                            result.add({
                                                transactionId = transactionId;
                                                index = index;
                                                amount = amount;
                                                scriptPublicKey = scriptPublicKey;
                                                scriptVersion = scriptVersion; // Default to 0
                                                address = utxoAddress;
                                            });
                                        };
                                        case _ {
                                            Debug.print("🚨 Unexpected UTXO JSON format: not an object");
                                            return null;
                                        };
                                    };
                                };
                                ?Buffer.toArray(result)
                            };
                            case _ {
                                Debug.print("🚨 Unexpected UTXO JSON format: not an array");
                                null
                            };
                        }
                    };
                }
            };
            case (_) {
                let decoded_text = switch (Text.decodeUtf8(response.body)) {
                    case (null) { "No value returned" };
                    case (?text) { text };
                };
                Debug.print("🚨 UTXO fetch failed: Status " # Nat.toText(response.status) # ", Body: " # decoded_text);
                null
            };
        }
    };

    // Transform function to strip headers for consensus
    public shared query func transform({ context : Blob; response : IC.http_request_result }) : async IC.http_request_result {
        {
            response with headers = [];
        }
    };

    private func get_ecdsa_pubkey() : async ?Blob {
        try {
            Cycles.add<system>(30_000_000_000);
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
        // --- Check for dust output ---
        if (amount < DUST_THRESHOLD) {
            Debug.print("🚨 Output amount " # Nat64.toText(amount) # " sompi is below dust threshold of " # Nat64.toText(DUST_THRESHOLD) # " sompi");
            return null;
        };

        // --- Decode recipient address ---
        let decoded = Address.decode_address(recipient_address);
        switch (decoded) {
            case (null) {
                Debug.print("🚨 Invalid recipient address");
                return null;
            };
            case (? (recipient_addr_type, pubkey)) {
                // --- Convert pubkey to hex for debugging ---
                let pubkey_hex = Address.hex_from_array(pubkey);
                Debug.print("Recipient decoded address: type=" # Nat.toText(recipient_addr_type) # ", pubkey=" # pubkey_hex);

                // --- Convert to scriptPublicKey ---
                let recipient_script = Address.pubkey_to_script(pubkey, recipient_addr_type);
                if (recipient_script == "") {
                    Debug.print("🚨 Failed to generate recipient scriptPublicKey");
                    return null;
                };
                Debug.print("Recipient scriptPublicKey: " # recipient_script);

                // --- Get sender's scriptPublicKey for change output ---
                let maybe_pk = await get_ecdsa_pubkey();
                let change_script = switch (maybe_pk) {
                    case (null) {
                        Debug.print("🚨 Failed to fetch ECDSA public key for change address");
                        return null;
                    };
                    case (?pk) {
                        let addr = Address.address_from_pubkey(pk, Address.ECDSA);
                        if (addr == "") {
                            Debug.print("🚨 Failed to generate change address");
                            return null;
                        };
                        let decoded_addr = Address.decode_address(addr);
                        switch (decoded_addr) {
                            case (null) {
                                Debug.print("🚨 Failed to decode change address");
                                return null;
                            };
                            case (? (_, change_pubkey)) {
                                Address.pubkey_to_script(change_pubkey, Address.ECDSA)
                            };
                        };
                    };
                };
                if (change_script == "") {
                    Debug.print("🚨 Failed to generate change scriptPublicKey");
                    return null;
                };
                Debug.print("Change scriptPublicKey: " # change_script);


                // --- Fetch UTXO dynamically ---
                let sender_address = await get_kaspa_address();
                let utxos = await fetch_utxos(sender_address);
                let utxo = switch (utxos) {
                    case (null) {
                        Debug.print("🚨 No UTXOs found for address " # sender_address);
                        return null;
                    };
                    case (?utxo_array) {
                        // Debug UTXO array for inspection
                        Debug.print("Fetched UTXOs: " # debug_show(utxo_array));
                        // Select the UTXO with the highest amount that meets the threshold
                        var selected_utxo: ?Types.UTXO = null;
                        var max_amount: Nat64 = 0;
                        for (u in utxo_array.vals()) {
                            Debug.print("Evaluating UTXO: txid=" # u.transactionId # ", amount=" # Nat64.toText(u.amount));
                            if (u.amount >= amount + 10_000 and u.amount > max_amount) {
                                selected_utxo := ?u;
                                max_amount := u.amount;
                            };
                        };
                        switch (selected_utxo) {
                            case (null) {
                                Debug.print("🚨 No suitable UTXO found with sufficient funds");
                                return null;
                            };
                            case (?u) {
                                Debug.print("Selected UTXO: txid=" # u.transactionId # ", amount=" # Nat64.toText(u.amount));
                                u
                            }
                        }
                    };
                };

                // --- Build transaction ---
                // let tx: Types.KaspaTransaction = Transaction.build_transaction(
                //     utxo,
                //     recipient_script,
                //     amount,
                //     10_000  // fee
                // );
                // --- Build transaction ---
                let tx: Types.KaspaTransaction = Transaction.build_transaction(
                    utxo,
                    recipient_script,
                    amount,
                    10_000, // Explicit fee
                    change_script // Pass sender's scriptPublicKey for change
                );

                if (tx.inputs.size() == 0) {
                    Debug.print("🚨 Transaction build failed: insufficient funds or invalid UTXO");
                    return null;
                };

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
                // if (addr_type == Address.ECDSA) {
                //     sighash_digest := Sighash.calculate_sighash_ecdsa(tx, 0, utxo, Sighash.SigHashAll, reused);
                // } else {
                //     Debug.print("Unsupported addr_type for signing");
                //     return null;
                // };
                sighash_digest := Sighash.calculate_sighash_ecdsa(tx, 0, utxo, Sighash.SigHashAll, reused);

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

                Debug.print("🔍 Recipient script: " # recipient_script);
                Debug.print("🔍 Change script: " # change_script);
                Debug.print("🔍 Transaction before signing: " # debug_show(tx));

                // --- Serialize signed transaction ---
                let serialized_tx = Transaction.serialize_transaction(signed_tx);
                Debug.print("Serialized signed transaction: " # serialized_tx);
                return ?serialized_tx;

                // --- Submit transaction to Kaspa mainnet ---
                // let submission_result = await Transaction.submit_transaction(serialized_tx);
                // switch (submission_result) {
                //     case (null) {
                //         Debug.print("🚨 Failed to submit transaction to Kaspa mainnet");
                //         return null;
                //     };
                //     case (?tx_id) {
                //         Debug.print("✅ Transaction submitted successfully: " # tx_id);
                //         return ?tx_id;
                //     };
                // };
            };
        }
    };
};