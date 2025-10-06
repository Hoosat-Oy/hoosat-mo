import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
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

import Address "../../src/address";
import Transaction "../../src/transaction";
import Types "../../src/types";
import SighashHoosat "../../src/sighash";
import Wallet "../../src/wallet";

// Updated modules with improved error handling
import Result "mo:base/Result";
import Errors "../../src/errors";
import Validation "../../src/validation";

persistent actor {
    private let key_id = "dfx_test_key";
    private let DUST_THRESHOLD : Nat64 = 1_000; // Minimum output amount in sompi

    transient let wallet = Wallet.createMainnetWallet("dfx_test_key", ?"hoosat");

    // Hoosat uses Blake3 instead of Blake2b for signature hashing
    // This implementation uses the Blake3 library via SighashHoosat module

    private func sign_digest(digest: [Nat8]) : async ?[Nat8] {
        try {
            let sig = await (with cycles = 30_000_000_000) IC.sign_with_ecdsa({
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

    // Parse derivation path (e.g., "44'/111111'/0'/0/0") to [Blob]
    private func parseDerivationPath(path: Text) : ?[Blob] {
        if (path == "") {
            return ?[];
        };
        let parts = Text.split(path, #char '/');
        let result = Buffer.Buffer<Blob>(0);
        for (part in parts) {
            // Remove trailing ' for hardened keys
            let cleaned = if (Text.endsWith(part, #char '\'')) {
                Text.trimEnd(part, #char '\'')
            } else {
                part
            };
            switch (textToNat32(cleaned)) {
                case (null) {
                    Debug.print("🚨 Invalid derivation path component: " # part);
                    return null;
                };
                case (?n) {
                    result.add(nat32ToBlob(n));
                };
            };
        };
        ?Buffer.toArray(result)
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

    // Helper function to convert Text number to Nat32
    private func textToNat32(text: Text) : ?Nat32 {
        let chars = Text.toIter(text);
        var num: Nat = 0;
        for (c in chars) {
            if (c < '0' or c > '9') {
                return null;
            };
            num := num * 10 + Nat32.toNat(Char.toNat32(c) - Char.toNat32('0'));
        };
        if (num > Nat32.toNat(Nat32.maximumValue)) {
            return null;
        };
        ?Nat32.fromNat(num)
    };

    // Convert Nat32 to 4-byte Blob (little-endian)
    private func nat32ToBlob(n: Nat32) : Blob {
        let bytes = Buffer.Buffer<Nat8>(4);
        bytes.add(Nat8.fromNat(Nat32.toNat(n & 0xFF)));
        bytes.add(Nat8.fromNat(Nat32.toNat((n >> 8) & 0xFF)));
        bytes.add(Nat8.fromNat(Nat32.toNat((n >> 16) & 0xFF)));
        bytes.add(Nat8.fromNat(Nat32.toNat((n >> 24) & 0xFF)));
        Blob.fromArray(Buffer.toArray(bytes))
    };

    // Fetch UTXOs for an address from Hoosat mainnet
    public func fetch_utxos(address: Text) : async ?[Types.UTXO] {
        let host = "api.network.hoosat.fi";
        let url = "https://" # host # "/addresses/" # address # "/utxos";
        let request_headers = [
            { name = "Content-Type"; value = "application/json" },
            { name = "User-Agent"; value = "hoosat-transaction-canister" }
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

        let response = await (with cycles = 230_949_972_000) IC.http_request(http_request);

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

    private func sign_digest_schnorr(digest: [Nat8]) : async ?[Nat8] {
        try {
            let sig = await (with cycles = 30_000_000_000) IC.sign_with_schnorr({
                message = Blob.fromArray(digest);
                derivation_path = [];
                key_id = { algorithm = #bip340secp256k1; name = key_id };
                aux = null;
            });
            ?Blob.toArray(sig.signature)
        } catch (e) {
            Debug.print("Schnorr signing failed: " # Error.message(e));
            null
        }
    };

    private func get_schnorr_pubkey(derivation_path: ?Text) : async ?Blob {
        try {
            let path = switch (derivation_path) {
                case (null) {
                    Debug.print("🔍 Using empty derivation path for Schnorr (null)");
                    []
                };
                case (?text) {
                    Debug.print("🔍 Parsing Schnorr derivation path: " # text);
                    switch (parseDerivationPath(text)) {
                        case (null) {
                            Debug.print("🚨 Failed to parse Schnorr derivation path: " # text);
                            return null;
                        };
                        case (?p) {
                            Debug.print("🔍 Parsed Schnorr derivation path has " # Nat.toText(p.size()) # " components");
                            p
                        };
                    };
                };
            };
            Debug.print("Using derivation path for Schnorr: " # debug_show(path));

            let pk = await (with cycles = 30_000_000_000) IC.schnorr_public_key({
                canister_id = null;
                derivation_path = path;
                key_id = { algorithm = #bip340secp256k1; name = key_id };
            });
            Debug.print("Schnorr public key length: " # Nat.toText(pk.public_key.size()));
            Debug.print("Schnorr public key hex: " # Address.hex_from_array(Blob.toArray(pk.public_key)));

            // Extract x-only public key (32 bytes) from compressed key (33 bytes)
            let pubkey_bytes = Blob.toArray(pk.public_key);
            if (pubkey_bytes.size() == 33) {
                // Remove the first byte (compression prefix) to get 32-byte x-only key
                let x_only_key = Array.tabulate<Nat8>(32, func(i) = pubkey_bytes[i + 1]);
                Debug.print("X-only public key hex: " # Address.hex_from_array(x_only_key));
                ?Blob.fromArray(x_only_key)
            } else {
                ?pk.public_key
            }
        } catch (e) {
            Debug.print("Schnorr fetch failed: " # Error.message(e));
            null
        }
    };

    private func get_ecdsa_pubkey(derivation_path: ?Text) : async ?Blob {
        try {

            let path = switch (derivation_path) {
                case (null) {
                    Debug.print("🔍 Using empty derivation path (null)");
                    []
                };
                case (?text) {
                    Debug.print("🔍 Parsing derivation path: " # text);
                    switch (parseDerivationPath(text)) {
                        case (null) {
                            Debug.print("🚨 Failed to parse derivation path: " # text);
                            return null;
                        };
                        case (?p) {
                            Debug.print("🔍 Parsed derivation path has " # Nat.toText(p.size()) # " components");
                            p
                        };
                    };
                };
            };
            Debug.print("Using derivation path: " # debug_show(path));

            let pk = await (with cycles = 30_000_000_000) IC.ecdsa_public_key({
                canister_id = null;
                derivation_path = path;
                key_id = { curve = #secp256k1; name = key_id };
            });
            ?pk.public_key
        } catch (e) {
            Debug.print("ECDSA fetch failed: " # Error.message(e));
            null
        }
    };

    // Schnorr address generation for Hoosat
    public func get_hoosat_address_schnorr(derivation_path: ?Text) : async Text {
        let maybe_pk = await get_schnorr_pubkey(derivation_path);
        switch (maybe_pk) {
            case (null) {
                Debug.print("🚨 Failed to fetch Schnorr public key");
                "";
            };
            case (?pk) {
                switch (Address.generateAddress(pk, 0, ?"hoosat")) { // 0 = SCHNORR, hoosat prefix
                    case (#err(error)) {
                        Debug.print("🚨 Failed to generate Hoosat Schnorr address: " # Errors.errorToText(error));
                        "";
                    };
                    case (#ok(result)) { result.address };
                }
            };
        }
    };

    // Main address generation using improved modules
    public func get_hoosat_address(derivation_path: ?Text) : async Text {
        let maybe_pk = await get_ecdsa_pubkey(derivation_path);
        switch (maybe_pk) {
            case (null) {
                Debug.print("🚨 Failed to fetch ECDSA public key");
                "";
            };
            case (?pk) {
                switch (Address.generateAddress(pk, 1, ?"hoosat")) { // 1 = ECDSA, pk is already Blob
                    case (#err(error)) {
                        Debug.print("🚨 Failed to generate Hoosat address: " # Errors.errorToText(error));
                        "";
                    };
                    case (#ok(result)) { result.address };
                }
            };
        }
    };

    // Test validation functionality
    public func test_validation(address: Text, amount: Nat64) : async Text {
        switch (Validation.validateAddress(address)) {
            case (#err(error)) {
                "Address validation failed: " # Errors.errorToText(error);
            };
            case (#ok(_)) {
                switch (Validation.validateAmount(amount, true)) { // Include dust check
                    case (#err(error)) {
                        "Amount validation failed: " # Errors.errorToText(error);
                    };
                    case (#ok(_)) {
                        "✅ Validation passed for address and amount";
                    };
                }
            };
        }
    };

    // Test function to compare Motoko and Go signature hash calculations
    public func test_sighash_calculation() : async Text {
        // Create the same transaction as in the Go test
        let tx: Types.HoosatTransaction = {
            version = 0;
            inputs = [
                {
                    previousOutpoint = {
                        transactionId = "999f36d9e74b646db3069ad9fab54edb1464445ce083f4e468b7c9f23c7b723f";
                        index = 1;
                    };
                    signatureScript = "";
                    sequence = 0;
                    sigOpCount = 1;
                }
            ];
            outputs = [
                {
                    amount = 1000;
                    scriptPublicKey = {
                        version = 0;
                        scriptPublicKey = "21020364e0d91f4557595ec5a1eda471b4c973cf01a1c2829ebc9b476aafc8ee23e3ab";
                    };
                },
                {
                    amount = 19999923000;
                    scriptPublicKey = {
                        version = 0;
                        scriptPublicKey = "210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab";
                    };
                }
            ];
            lockTime = 0;
            subnetworkId = "0000000000000000000000000000000000000000";
            gas = 0;
            payload = "";
        };

        // Create the UTXO
        let utxo: Types.UTXO = {
            transactionId = "999f36d9e74b646db3069ad9fab54edb1464445ce083f4e468b7c9f23c7b723f";
            index = 1;
            amount = 19999934000;
            scriptPublicKey = "210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab";
            scriptVersion = 0;
            address = "hoosat:qypff6urmgk8452vjx55r63dhc38s6ewlavknmnefzgac42n3lt8cdchea953un";
        };

        // Prepare reused values for sighash
        var reused: SighashHoosat.SighashReusedValues = {
            var previousOutputsHash = null;
            var sequencesHash = null;
            var sigOpCountsHash = null;
            var outputsHash = null;
            var payloadHash = null;
        };

        // Calculate ECDSA sighash
        let ecdsa_sighash = SighashHoosat.calculate_sighash_ecdsa(tx, 0, utxo, SighashHoosat.SigHashAll, reused);
        let ecdsa_result = switch (ecdsa_sighash) {
            case (null) { "Failed to calculate ECDSA sighash" };
            case (?hash) { Address.hex_from_array(hash) };
        };

        // Calculate Schnorr sighash
        var reused2: SighashHoosat.SighashReusedValues = {
            var previousOutputsHash = null;
            var sequencesHash = null;
            var sigOpCountsHash = null;
            var outputsHash = null;
            var payloadHash = null;
        };
        let schnorr_sighash = SighashHoosat.calculate_sighash_schnorr(tx, 0, utxo, SighashHoosat.SigHashAll, reused2);
        let schnorr_result = switch (schnorr_sighash) {
            case (null) { "Failed to calculate Schnorr sighash" };
            case (?hash) { Address.hex_from_array(hash) };
        };

        "Motoko ECDSA Sighash: " # ecdsa_result # "\nMotoko Schnorr Sighash: " # schnorr_result
    };

    public func send_hoosat_schnorr(
        recipient_address: Text,
        amount: Nat64
    ) : async ?Text {
        // --- Check for dust output ---
        if (amount < DUST_THRESHOLD) {
            Debug.print("🚨 Output amount " # Nat64.toText(amount) # " sompi is below dust threshold of " # Nat64.toText(DUST_THRESHOLD) # " sompi");
            return null;
        };

        // --- Decode recipient address ---
        let decoded = Address.decodeAddress(recipient_address, ?"hoosat");
        switch (decoded) {
            case (#err(error)) {
                Debug.print("🚨 Invalid recipient address: " # Errors.errorToText(error));
                return null;
            };
            case (#ok(addressInfo)) {
                let recipient_addr_type = addressInfo.addr_type;
                let pubkey = addressInfo.payload;
                // --- Convert pubkey to hex for debugging ---
                let pubkey_hex = Address.hex_from_array(pubkey);
                Debug.print("Recipient decoded address: type=" # Nat.toText(recipient_addr_type) # ", pubkey=" # pubkey_hex);

                // --- Use the script public key from decoded address ---
                let recipient_script = addressInfo.script_public_key;
                Debug.print("Recipient scriptPublicKey: " # recipient_script);

                // --- Get sender's Schnorr scriptPublicKey for change output ---
                let maybe_pk = await get_schnorr_pubkey(null);
                let change_script = switch (maybe_pk) {
                    case (null) {
                        Debug.print("🚨 Failed to fetch Schnorr public key for change address");
                        return null;
                    };
                    case (?pk) {
                        switch (Address.generateAddress(pk, Address.SCHNORR, ?"hoosat")) {
                            case (#err(error)) {
                                Debug.print("🚨 Failed to generate change address: " # Errors.errorToText(error));
                                return null;
                            };
                            case (#ok(result)) {
                                result.script_public_key
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
                let sender_address = await get_hoosat_address_schnorr(null);
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

                // --- Build transaction with normal fee to test multiple outputs with SigHashAll ---
                let tx: Types.HoosatTransaction = Transaction.build_transaction(
                    utxo,
                    recipient_script,
                    amount,
                    10_000, // Normal fee to create change output
                    change_script // Pass sender's scriptPublicKey for change
                );

                if (tx.inputs.size() == 0) {
                    Debug.print("🚨 Transaction build failed: insufficient funds or invalid UTXO");
                    return null;
                };

                Debug.print("🔍 Testing SigHashAll with multiple outputs:");
                Debug.print("🔍 Number of outputs: " # Nat.toText(tx.outputs.size()));
                for (i in tx.outputs.keys()) {
                    let output = tx.outputs[i];
                    Debug.print("🔍 Output " # Nat.toText(i) # ": amount=" # Nat64.toText(output.amount) # ", script=" # output.scriptPublicKey.scriptPublicKey);
                };

                // --- Prepare reused values for sighash ---
                var reused: SighashHoosat.SighashReusedValues = {
                    var previousOutputsHash = null;
                    var sequencesHash = null;
                    var sigOpCountsHash = null;
                    var outputsHash = null;
                    var payloadHash = null;
                };

                // --- Calculate digest using Hoosat Schnorr sighash ---
                var sighash_digest: ?[Nat8] = null;
                sighash_digest := SighashHoosat.calculate_sighash_schnorr(tx, 0, utxo, SighashHoosat.SigHashAll, reused);

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
                Debug.print("Digest length: " # Nat.toText(digest.size()));

                // --- Sign digest with Schnorr ---
                let signature_opt: ?[Nat8] = await sign_digest_schnorr(digest);

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
                Debug.print("Signature length: " # Nat.toText(signature.size()));

                // --- Build signatureScript for Schnorr (64 bytes + 1 hashType) ---
                let signature_script = Buffer.Buffer<Nat8>(0);
                signature_script.add(65); // OP_DATA_65 (length of 64-byte signature + 1-byte hashType)
                signature_script.append(Buffer.fromArray(signature));
                signature_script.add(SighashHoosat.SigHashAll); // Append hashType (0x01)

                let signature_script_hex = Address.hex_from_array(Buffer.toArray(signature_script));
                Debug.print("Complete signature script (hex): " # signature_script_hex);
                Debug.print("Signature script length: " # Nat.toText(Buffer.toArray(signature_script).size()));

                // --- Update transaction input with signatureScript ---
                let updated_inputs = Array.mapEntries(tx.inputs, func (input: Types.TransactionInput, i: Nat) : Types.TransactionInput {
                    if (i == 0) {
                        { input with signatureScript = Address.hex_from_array(Buffer.toArray(signature_script)) }
                    } else {
                        input
                    }
                });

                let signed_tx: Types.HoosatTransaction = {
                    tx with inputs = updated_inputs
                };

                Debug.print("🔍 Recipient script: " # recipient_script);
                Debug.print("🔍 Change script: " # change_script);
                Debug.print("🔍 Transaction before signing: " # debug_show(tx));
                Debug.print("🔍 Number of outputs: " # Nat.toText(tx.outputs.size()));
                for (i in tx.outputs.keys()) {
                    let output = tx.outputs[i];
                    Debug.print("🔍 Output " # Nat.toText(i) # ": amount=" # Nat64.toText(output.amount) # ", script=" # output.scriptPublicKey.scriptPublicKey);
                };

                // --- Serialize signed transaction ---
                let serialized_tx = Transaction.serialize_transaction(signed_tx);
                Debug.print("Serialized signed transaction: " # serialized_tx);
                // Broadcast using wallet instance
                let broadcast_result = await wallet.broadcastSerializedTransaction(serialized_tx);
                switch (broadcast_result) {
                    case (#err(error)) {
                        Debug.print("🚨 Failed to submit transaction to Hoosat mainnet: " # Errors.errorToText(error));
                        return null;
                    };
                    case (#ok(tx_id)) {
                        Debug.print("✅ Transaction submitted successfully: " # tx_id);
                        return ?tx_id;
                    };
                };
            };
        }
    };

    public func send_hoosat(
        recipient_address: Text,
        amount: Nat64
    ) : async ?Text {
        // Create a Wallet instance for mainnet
        // --- Check for dust output ---
        if (amount < DUST_THRESHOLD) {
            Debug.print("🚨 Output amount " # Nat64.toText(amount) # " sompi is below dust threshold of " # Nat64.toText(DUST_THRESHOLD) # " sompi");
            return null;
        };

        // --- Decode recipient address ---
        let decoded = Address.decodeAddress(recipient_address, ?"hoosat");
        switch (decoded) {
            case (#err(error)) {
                Debug.print("🚨 Invalid recipient address: " # Errors.errorToText(error));
                return null;
            };
            case (#ok address_info) {
                // --- Convert pubkey to hex for debugging ---
                let pubkey_hex = Address.hex_from_array(address_info.payload);
                Debug.print("Recipient decoded address: type=" # Nat.toText(address_info.addr_type) # ", pubkey=" # pubkey_hex);

                // --- Convert to scriptPublicKey ---
                let recipient_script = Address.pubkey_to_script(address_info.payload, address_info.addr_type);
                if (recipient_script == "") {
                    Debug.print("🚨 Failed to generate recipient scriptPublicKey");
                    return null;
                };
                Debug.print("Recipient scriptPublicKey: " # recipient_script);

                // --- Get sender's scriptPublicKey for change output ---
                let maybe_pk = await get_ecdsa_pubkey(null);
                let change_script = switch (maybe_pk) {
                    case (null) {
                        Debug.print("🚨 Failed to fetch ECDSA public key for change address");
                        return null;
                    };
                    case (?pk) {
                        let addr_result = Address.generateAddress(pk, Address.ECDSA, ?"hoosat");
                        switch (addr_result) {
                            case (#err(error)) {
                                Debug.print("🚨 Failed to generate change address: " # Errors.errorToText(error));
                                return null;
                            };
                            case (#ok addr_info) {
                                let decoded_addr = Address.decodeAddress(addr_info.address, ?"hoosat");
                                switch (decoded_addr) {
                                    case (#err(error)) {
                                        Debug.print("🚨 Failed to decode change address: " # Errors.errorToText(error));
                                        return null;
                                    };
                                    case (#ok change_address_info) {
                                        Address.pubkey_to_script(change_address_info.payload, change_address_info.addr_type)
                                    };
                                };
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
                let sender_address = await get_hoosat_address(null);
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
                let tx: Types.HoosatTransaction = Transaction.build_transaction(
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
                var reused: SighashHoosat.SighashReusedValues = {
                    var previousOutputsHash = null;
                    var sequencesHash = null;
                    var sigOpCountsHash = null;
                    var outputsHash = null;
                    var payloadHash = null;
                };

                // --- Calculate digest ---
                var sighash_digest: ?[Nat8] = null;
                sighash_digest := SighashHoosat.calculate_sighash_ecdsa(tx, 0, utxo, SighashHoosat.SigHashAll, reused);

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
                signature_script.add(SighashHoosat.SigHashAll); // Append hashType (0x01)

                // --- Update transaction input with signatureScript ---
                let updated_inputs = Array.mapEntries(tx.inputs, func (input: Types.TransactionInput, i: Nat) : Types.TransactionInput {
                    if (i == 0) {
                        { input with signatureScript = Address.hex_from_array(Buffer.toArray(signature_script)) }
                    } else {
                        input
                    }
                });

                let signed_tx: Types.HoosatTransaction = {
                    tx with inputs = updated_inputs
                };

                Debug.print("🔍 Recipient script: " # recipient_script);
                Debug.print("🔍 Change script: " # change_script);
                Debug.print("🔍 Transaction before signing: " # debug_show(tx));

                // --- Serialize signed transaction ---
                let serialized_tx = Transaction.serialize_transaction(signed_tx);
                Debug.print("Serialized signed transaction: " # serialized_tx);
                // Broadcast using wallet instance
                let broadcast_result = await wallet.broadcastSerializedTransaction(serialized_tx);
                switch (broadcast_result) {
                    case (#err(error)) {
                        Debug.print("🚨 Failed to submit transaction to Hoosat mainnet: " # Errors.errorToText(error));
                        return null;
                    };
                    case (#ok(tx_id)) {
                        Debug.print("✅ Transaction submitted successfully: " # tx_id);
                        return ?tx_id;
                    };
                }
            };
        }
    };
};