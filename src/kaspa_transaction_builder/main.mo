import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Nat8 "mo:base/Nat8";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Cycles "mo:base/ExperimentalCycles";
import Error "mo:base/Error";
import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import Time "mo:base/Time";

import Sha256 "mo:sha2/Sha256";

import Address "../kaspa/address";

persistent actor KaspaTransactionBuilder {

    // Management canister interface for ECDSA
    let management_canister = actor("aaaaa-aa") : actor {
        ecdsa_public_key : {
            canister_id : ?Principal;
            derivation_path : [Blob];
            key_id : { curve : { #secp256k1 }; name : Text }
        } -> async { public_key : Blob; chain_code : Blob };
        
        sign_with_ecdsa : {
            message_hash : Blob;
            derivation_path : [Blob];
            key_id : { curve : { #secp256k1 }; name : Text }
        } -> async { signature : Blob };
    };

    // Kaspa transaction data structures
    public type KaspaOutpoint = {
        transactionId: Text;
        index: Nat;
    };

    public type KaspaInput = {
        previousOutpoint: KaspaOutpoint;
        signatureScript: Text;
        sequence: Nat64;
        sigOpCount: Nat;
    };

    public type KaspaScriptPublicKey = {
        version: Nat;
        scriptPublicKey: Text;
    };

    public type KaspaOutput = {
        amount: Nat64; // Amount in sompi (smallest unit)
        scriptPublicKey: KaspaScriptPublicKey;
    };

    public type KaspaTransaction = {
        version: Nat;
        inputs: [KaspaInput];
        outputs: [KaspaOutput];
        lockTime: Nat64;
        subnetworkId: Text;
    };

    public type TransactionRequest = {
        transaction: KaspaTransaction;
        allowOrphan: Bool;
    };

    public type UTXO = {
        transactionId: Text;
        index: Nat;
        amount: Nat64;
        scriptPublicKey: Text;
        address: Text;
    };

    // Helper: Convert to compressed format if needed
    private func to_compressed_public_key(public_key: Blob) : ?Blob {
        let key_bytes = Blob.toArray(public_key);
        
        if (key_bytes.size() == 33 and (key_bytes[0] == 0x02 or key_bytes[0] == 0x03)) {
            ?public_key
        } else if (key_bytes.size() == 65 and key_bytes[0] == 0x04) {
            let x_bytes = Array.subArray<Nat8>(key_bytes, 1, 32);
            let y_bytes = Array.subArray<Nat8>(key_bytes, 33, 32);
            let y_is_even = (y_bytes[31] % 2) == 0;
            let prefix : Nat8 = if (y_is_even) 0x02 else 0x03;
            let compressed = Array.append<Nat8>([prefix], x_bytes);
            ?Blob.fromArray(compressed)
        } else {
            null
        }
    };

    // Helper: Convert array to hex
    private func hex_from_array(bytes: [Nat8]) : Text {
        let hexChars = ['0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f'];
        var result = "";
        for (byte in bytes.vals()) {
            let high = Nat8.toNat(byte / 16);
            let low = Nat8.toNat(byte % 16);
            result := result # Text.fromChar(hexChars[high]) # Text.fromChar(hexChars[low]);
        };
        result
    };

    // Helper: Convert hex string to bytes (for parsing scriptPublicKey)
    private func hex_to_bytes(hex: Text) : ?[Nat8] {
        let chars = Text.toArray(hex);
        if (chars.size() % 2 != 0) return null;
        
        let bytes = Buffer.Buffer<Nat8>(chars.size() / 2);
        var i = 0;
        while (i < chars.size()) {
            let high = char_to_hex(chars[i]);
            let low = char_to_hex(chars[i + 1]);
            switch (high, low) {
                case (?h, ?l) {
                    bytes.add(Nat8.fromNat(h * 16 + l));
                    i += 2;
                };
                case _ return null;
            };
        };
        ?Buffer.toArray(bytes)
    };

    private func char_to_hex(c: Char) : ?Nat {
        switch (c) {
            case ('0') ?0; case ('1') ?1; case ('2') ?2; case ('3') ?3; case ('4') ?4;
            case ('5') ?5; case ('6') ?6; case ('7') ?7; case ('8') ?8; case ('9') ?9;
            case ('a' or 'A') ?10; case ('b' or 'B') ?11; case ('c' or 'C') ?12;
            case ('d' or 'D') ?13; case ('e' or 'E') ?14; case ('f' or 'F') ?15;
            case _ null;
        }
    };

    // Generate a Kaspa address and get its scriptPublicKey
    public func generate_address_with_script(derivation_path: Text) : async {address: Text; scriptPublicKey: Text; publicKey: Text} {
        try {
            Cycles.add<system>(30_000_000_000);
            
            let result = await management_canister.ecdsa_public_key({
                canister_id = null;
                derivation_path = [Text.encodeUtf8(derivation_path)];
                key_id = { curve = #secp256k1; name = "dfx_test_key" };
            });
            
            let compressed_key_opt = to_compressed_public_key(result.public_key);
            switch (compressed_key_opt) {
                case (null) {
                    { address = ""; scriptPublicKey = ""; publicKey = "" }
                };
                case (?compressed_key) {
                    let kaspa_address = Address.address_from_pubkey(compressed_key, Address.ECDSA);
                    let pub_key_hex = hex_from_array(Blob.toArray(compressed_key));
                    
                    // Create P2PK (Pay to Public Key) script: OP_DATA_33 <pubkey> OP_CHECKSIG
                    // In Kaspa: 0x21 (33 bytes) + pubkey + 0xac (OP_CHECKSIG)
                    let script_hex = "21" # pub_key_hex # "ac";
                    
                    { 
                        address = kaspa_address; 
                        scriptPublicKey = script_hex;
                        publicKey = pub_key_hex;
                    }
                };
            };
        } catch (err) {
            Debug.print("Error generating address: " # Error.message(err));
            { address = ""; scriptPublicKey = ""; publicKey = "" }
        };
    };

    // Create a simple transaction hash for signing (simplified version)
    private func create_transaction_hash(
        inputs: [KaspaInput],
        outputs: [KaspaOutput], 
        version: Nat,
        lockTime: Nat64,
        subnetworkId: Text
    ) : [Nat8] {
        // This is a simplified transaction hash - in production you'd need
        // to serialize the entire transaction according to Kaspa's format
        let buffer = Buffer.Buffer<Nat8>(1024);
        
        // Add version (4 bytes little-endian)
        let version_bytes = nat_to_le_bytes(version, 4);
        buffer.append(Buffer.fromArray(version_bytes));
        
        // Add inputs count
        buffer.add(Nat8.fromNat(inputs.size()));
        for (input in inputs.vals()) {
            // Add previous outpoint transaction ID (32 bytes)
            switch (hex_to_bytes(input.previousOutpoint.transactionId)) {
                case (?tx_bytes) buffer.append(Buffer.fromArray(tx_bytes));
                case null {}; // Skip invalid hex
            };
            // Add outpoint index (4 bytes little-endian)
            let index_bytes = nat_to_le_bytes(input.previousOutpoint.index, 4);
            buffer.append(Buffer.fromArray(index_bytes));
        };
        
        // Add outputs count
        buffer.add(Nat8.fromNat(outputs.size()));
        for (output in outputs.vals()) {
            // Add amount (8 bytes little-endian)
            let amount_bytes = nat64_to_le_bytes(output.amount);
            buffer.append(Buffer.fromArray(amount_bytes));
        };
        
        // Add lockTime (8 bytes little-endian)
        let locktime_bytes = nat64_to_le_bytes(lockTime);
        buffer.append(Buffer.fromArray(locktime_bytes));
        
        // Hash the serialized data
        Blob.toArray(Sha256.fromBlob(#sha256, Blob.fromArray(Buffer.toArray(buffer))))
    };

    // Helper: Convert Nat to little-endian bytes
    private func nat_to_le_bytes(n: Nat, size: Nat) : [Nat8] {
        let bytes = Array.init<Nat8>(size, 0);
        var value = n;
        var i = 0;
        while (i < size and value > 0) {
            bytes[i] := Nat8.fromNat(value % 256);
            value := value / 256;
            i += 1;
        };
        Array.freeze(bytes)
    };

    // Helper: Convert Nat64 to little-endian bytes
    private func nat64_to_le_bytes(n: Nat64) : [Nat8] {
        let bytes = Array.init<Nat8>(8, 0);
        var value = n;
        var i = 0;
        while (i < 8) {
            bytes[i] := Nat8.fromNat(Nat64.toNat(value % 256));
            value := value / 256;
            i += 1;
        };
        Array.freeze(bytes)
    };

    // Sign a transaction input
    private func sign_transaction_input(
        tx_hash: [Nat8],
        input_index: Nat,
        derivation_path: Text
    ) : async ?Text {
        try {
            Cycles.add<system>(30_000_000_000);
            
            let signature_result = await management_canister.sign_with_ecdsa({
                message_hash = Blob.fromArray(tx_hash);
                derivation_path = [Text.encodeUtf8(derivation_path)];
                key_id = { curve = #secp256k1; name = "dfx_test_key" };
            });
            
            let sig_bytes = Blob.toArray(signature_result.signature);
            
            // Get the public key for this derivation path
            let pub_result = await management_canister.ecdsa_public_key({
                canister_id = null;
                derivation_path = [Text.encodeUtf8(derivation_path)];
                key_id = { curve = #secp256k1; name = "dfx_test_key" };
            });
            
            let compressed_key_opt = to_compressed_public_key(pub_result.public_key);
            switch (compressed_key_opt) {
                case (null) null;
                case (?compressed_key) {
                    let pub_key_hex = hex_from_array(Blob.toArray(compressed_key));
                    let sig_hex = hex_from_array(sig_bytes);
                    
                    // Create signature script: <signature> <pubkey>
                    // In Kaspa format: length + signature + SIGHASH_ALL + length + pubkey
                    let sig_len = Nat8.fromNat(sig_bytes.size() + 1); // +1 for SIGHASH_ALL
                    let pub_len = Nat8.fromNat(33); // Compressed pubkey is always 33 bytes
                    
                    let script = hex_from_array([sig_len]) # sig_hex # "01" # // SIGHASH_ALL = 0x01
                                hex_from_array([pub_len]) # pub_key_hex;
                    
                    ?script
                };
            };
        } catch (err) {
            Debug.print("Error signing input: " # Error.message(err));
            null
        };
    };

    // Build and sign a complete transaction
    public func build_transaction(
        utxos: [UTXO],
        to_address: Text,
        amount: Nat64,
        fee: Nat64,
        change_derivation_path: Text
    ) : async Result.Result<TransactionRequest, Text> {
        Debug.print("🏗️  Building Kaspa transaction...");
        Debug.print("   📊 UTXOs: " # Nat.toText(utxos.size()));
        Debug.print("   💰 Amount: " # Nat64.toText(amount) # " sompi");
        Debug.print("   💸 Fee: " # Nat64.toText(fee) # " sompi");
        
        // Calculate total input amount
        var total_input : Nat64 = 0;
        for (utxo in utxos.vals()) {
            total_input += utxo.amount;
        };
        
        if (total_input < amount + fee) {
            return #err("Insufficient funds: need " # Nat64.toText(amount + fee) # ", have " # Nat64.toText(total_input));
        };
        
        let change_amount = total_input - amount - fee;
        Debug.print("   🔄 Change: " # Nat64.toText(change_amount) # " sompi");
        
        try {
            // Generate change address
            let change_info = await generate_address_with_script(change_derivation_path);
            if (change_info.address == "") {
                return #err("Failed to generate change address");
            };
            
            // Build outputs
            let outputs_buffer = Buffer.Buffer<KaspaOutput>(2);
            
            // Main output to recipient
            outputs_buffer.add({
                amount = amount;
                scriptPublicKey = {
                    version = 0;
                    scriptPublicKey = to_address; // This should be the scriptPubKey, not address
                };
            });
            
            // Change output (if any)
            if (change_amount > 0) {
                outputs_buffer.add({
                    amount = change_amount;
                    scriptPublicKey = {
                        version = 0;
                        scriptPublicKey = change_info.scriptPublicKey;
                    };
                });
            };
            
            let outputs = Buffer.toArray(outputs_buffer);
            
            // Build unsigned inputs
            let inputs_buffer = Buffer.Buffer<KaspaInput>(utxos.size());
            for (utxo in utxos.vals()) {
                inputs_buffer.add({
                    previousOutpoint = {
                        transactionId = utxo.transactionId;
                        index = utxo.index;
                    };
                    signatureScript = ""; // Will be filled after signing
                    sequence = 0xffffffffffffffff; // Max sequence
                    sigOpCount = 1;
                });
            };
            
            var inputs = Buffer.toArray(inputs_buffer);
            
            // Create transaction hash for signing
            let tx_hash = create_transaction_hash(
                inputs,
                outputs,
                0, // version
                0, // lockTime
                "0000000000000000000000000000000000000000" // subnetworkId
            );
            
            Debug.print("   🔢 Transaction hash: " # hex_from_array(tx_hash));
            
            // Sign each input
            let signed_inputs_buffer = Buffer.Buffer<KaspaInput>(inputs.size());
            for (i in inputs.keys()) {
                let input = inputs[i];
                let utxo = utxos[i];
                
                // For this example, assume all UTXOs use the same derivation path
                // In practice, you'd track which path was used for each UTXO
                let signature_script_opt = await sign_transaction_input(
                    tx_hash,
                    i,
                    change_derivation_path // Using same path for simplicity
                );
                
                switch (signature_script_opt) {
                    case (null) {
                        return #err("Failed to sign input " # Nat.toText(i));
                    };
                    case (?sig_script) {
                        signed_inputs_buffer.add({
                            previousOutpoint = input.previousOutpoint;
                            signatureScript = sig_script;
                            sequence = input.sequence;
                            sigOpCount = input.sigOpCount;
                        });
                        Debug.print("   ✅ Signed input " # Nat.toText(i));
                    };
                };
            };
            
            let signed_inputs = Buffer.toArray(signed_inputs_buffer);
            
            let transaction : KaspaTransaction = {
                version = 0;
                inputs = signed_inputs;
                outputs = outputs;
                lockTime = 0;
                subnetworkId = "0000000000000000000000000000000000000000";
            };
            
            let request : TransactionRequest = {
                transaction = transaction;
                allowOrphan = false;
            };
            
            Debug.print("   🎉 Transaction built and signed successfully!");
            #ok(request)
            
        } catch (err) {
            #err("Transaction building failed: " # Error.message(err))
        };
    };

    // Test function to demonstrate usage
    public func test_transaction_building() : async () {
        Debug.print("\n🧪 === TESTING TRANSACTION BUILDING ===");
        
        // Generate test addresses
        let sender_info = await generate_address_with_script("test-sender");
        let recipient_info = await generate_address_with_script("test-recipient");
        
        Debug.print("   📫 Sender: " # sender_info.address);
        Debug.print("   📫 Recipient: " # recipient_info.address);
        Debug.print("   🔑 Sender scriptPubKey: " # sender_info.scriptPublicKey);
        
        // Mock UTXO (in practice, you'd get this from the API)
        let mock_utxos : [UTXO] = [{
            transactionId = "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";
            index = 0;
            amount = 1000000; // 0.01 KAS in sompi
            scriptPublicKey = sender_info.scriptPublicKey;
            address = sender_info.address;
        }];
        
        // Build transaction: send 500000 sompi with 10000 fee
        let result = await build_transaction(
            mock_utxos,
            recipient_info.scriptPublicKey, // Use scriptPubKey, not address
            500000, // 0.005 KAS
            10000,  // 0.0001 KAS fee
            "test-change"
        );
        
        switch (result) {
            case (#err(msg)) {
                Debug.print("   ❌ Transaction failed: " # msg);
            };
            case (#ok(tx_request)) {
                Debug.print("   ✅ Transaction created successfully!");
                Debug.print("   📋 Inputs: " # Nat.toText(tx_request.transaction.inputs.size()));
                Debug.print("   📋 Outputs: " # Nat.toText(tx_request.transaction.outputs.size()));
                Debug.print("   📋 Total outputs value: " # 
                    Nat64.toText(Array.foldLeft<KaspaOutput, Nat64>(
                        tx_request.transaction.outputs, 0, 
                        func(acc, output) = acc + output.amount
                    )) # " sompi");
            };
        };
        
        Debug.print("\n💡 Next steps:");
        Debug.print("1. Get real UTXOs from Kaspa API");
        Debug.print("2. Submit transaction to /transactions endpoint");
        Debug.print("3. Monitor transaction status");
    };
};