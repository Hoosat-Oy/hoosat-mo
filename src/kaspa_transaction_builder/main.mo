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













// import Debug "mo:base/Debug";
// import Blob "mo:base/Blob";
// import Array "mo:base/Array";
// import Text "mo:base/Text";
// import Nat8 "mo:base/Nat8";
// import Nat "mo:base/Nat";
// import Nat32 "mo:base/Nat32";
// import Nat64 "mo:base/Nat64";
// import Cycles "mo:base/ExperimentalCycles";
// import Error "mo:base/Error";
// import Principal "mo:base/Principal";
// import Buffer "mo:base/Buffer";
// import Result "mo:base/Result";
// import Iter "mo:base/Iter";
// import Sha256 "mo:sha2/Sha256";

// import Blake2b "mo:blake2b";
// import Address "../kaspa/address";

// persistent actor KaspaTransactionBuilder {
//     // Management canister interface for ECDSA
//     let management_canister = actor("aaaaa-aa") : actor {
//         ecdsa_public_key : {
//             canister_id : ?Principal;
//             derivation_path : [Blob];
//             key_id : { curve : { #secp256k1 }; name : Text }
//         } -> async { public_key : Blob; chain_code : Blob };
        
//         sign_with_ecdsa : {
//             message_hash : Blob;
//             derivation_path : [Blob];
//             key_id : { curve : { #secp256k1 }; name : Text }
//         } -> async { signature : Blob };
//     };

//     // Kaspa transaction data structures
//     public type KaspaOutpoint = {
//         transactionId: Text; // hex
//         index: Nat;
//     };

//     public type KaspaInput = {
//         previousOutpoint: KaspaOutpoint;
//         signatureScript: Text; // hex
//         sequence: Nat64;
//         sigOpCount: Nat;
//     };

//     public type KaspaScriptPublicKey = {
//         version: Nat;
//         scriptPublicKey: Text; // hex
//     };

//     public type KaspaOutput = {
//         amount: Nat64; // sompi
//         scriptPublicKey: KaspaScriptPublicKey;
//     };

//     public type KaspaTransaction = {
//         version: Nat;
//         inputs: [KaspaInput];
//         outputs: [KaspaOutput];
//         lockTime: Nat64;
//         subnetworkId: Text; // hex, 40 chars (20 bytes)
//         gas: Nat64;
//         payload: [Nat8]; // raw bytes (hex in JSON)
//     };

//     public type TransactionRequest = {
//         transaction: KaspaTransaction;
//         allowOrphan: Bool;
//     };

//     public type UTXO = {
//         transactionId: Text; // hex
//         index: Nat;
//         amount: Nat64; // sompi
//         scriptPublicKey: Text; // hex
//         scriptVersion: Nat; // typically 0
//         address: Text;
//     };

//     // Helper: Convert to compressed public key
//     private func to_compressed_public_key(public_key: Blob) : ?Blob {
//         let key_bytes = Blob.toArray(public_key);
        
//         if (key_bytes.size() == 33 and (key_bytes[0] == 0x02 or key_bytes[0] == 0x03)) {
//             ?public_key
//         } else if (key_bytes.size() == 65 and key_bytes[0] == 0x04) {
//             let x_bytes = Array.subArray<Nat8>(key_bytes, 1, 32);
//             let y_bytes = Array.subArray<Nat8>(key_bytes, 33, 32);
//             let y_is_even = (y_bytes[31] % 2) == 0;
//             let prefix : Nat8 = if (y_is_even) 0x02 else 0x03;
//             let compressed = Array.append<Nat8>([prefix], x_bytes);
//             ?Blob.fromArray(compressed)
//         } else {
//             null
//         }
//     };

//     // Helper: Convert array to hex
//     private func hex_from_array(bytes: [Nat8]) : Text {
//         let hexChars = ['0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f'];
//         var result = "";
//         for (byte in bytes.vals()) {
//             let high = Nat8.toNat(byte / 16);
//             let low = Nat8.toNat(byte % 16);
//             result := result # Text.fromChar(hexChars[high]) # Text.fromChar(hexChars[low]);
//         };
//         result
//     };

//     // Helper: Convert hex string to bytes
//     private func hex_to_bytes(hex: Text) : ?[Nat8] {
//         let chars = Text.toArray(hex);
//         if (chars.size() % 2 != 0) return null;
        
//         let bytes = Buffer.Buffer<Nat8>(chars.size() / 2);
//         var i = 0;
//         while (i < chars.size()) {
//             let high = char_to_hex(chars[i]);
//             let low = char_to_hex(chars[i + 1]);
//             switch (high, low) {
//                 case (?h, ?l) {
//                     bytes.add(Nat8.fromNat(h * 16 + l));
//                     i += 2;
//                 };
//                 case _ return null;
//             };
//         };
//         ?Buffer.toArray(bytes)
//     };

//     private func char_to_hex(c: Char) : ?Nat {
//         switch (c) {
//             case ('0') ?0; case ('1') ?1; case ('2') ?2; case ('3') ?3; case ('4') ?4;
//             case ('5') ?5; case ('6') ?6; case ('7') ?7; case ('8') ?8; case ('9') ?9;
//             case ('a' or 'A') ?10; case ('b' or 'B') ?11; case ('c' or 'C') ?12;
//             case ('d' or 'D') ?13; case ('e' or 'E') ?14; case ('f' or 'F') ?15;
//             case _ null;
//         }
//     };

//     // Helper: Convert Nat32 to little-endian bytes
//     private func nat32_to_bytes(n: Nat32) : [Nat8] {
//         let bytes = Array.init<Nat8>(4, 0);
//         var value = n;
//         var i = 0;
//         while (i < 4) {
//             bytes[i] := Nat8.fromNat(Nat32.toNat(value % 256));
//             value := value / 256;
//             i += 1;
//         };
//         Array.freeze(bytes)
//     };

//     // Helper: Convert derivation path Text to Blob array
//     private func text_to_derivation_path(path: Text) : [Blob] {
//         if (path == "sender") {
//             [
//                 Blob.fromArray(nat32_to_bytes(44 + 0x80000000)), // 44'
//                 Blob.fromArray(nat32_to_bytes(111111 + 0x80000000)), // 111111'
//                 Blob.fromArray(nat32_to_bytes(0 + 0x80000000)), // 0'
//                 Blob.fromArray(nat32_to_bytes(0)), // 0
//                 Blob.fromArray(nat32_to_bytes(0))  // 0
//             ]
//         } else if (path == "change") {
//             [
//                 Blob.fromArray(nat32_to_bytes(44 + 0x80000000)), // 44'
//                 Blob.fromArray(nat32_to_bytes(111111 + 0x80000000)), // 111111'
//                 Blob.fromArray(nat32_to_bytes(0 + 0x80000000)), // 0'
//                 Blob.fromArray(nat32_to_bytes(0)), // 0
//                 Blob.fromArray(nat32_to_bytes(1))  // 1
//             ]
//         } else {
//             [Blob.fromArray(nat32_to_bytes(0))]
//         }
//     };

//     // Helper: DER encode raw signature (64 bytes r+s)
//     private func der_encode_signature(raw_sig: [Nat8]) : [Nat8] {
//         if (raw_sig.size() != 64) return [];
//         let r = Array.subArray<Nat8>(raw_sig, 0, 32);
//         let s = Array.subArray<Nat8>(raw_sig, 32, 32);
//         let r_bytes = if (r[0] > 0x7F) Array.append<Nat8>([0x00], r) else r;
//         let s_bytes = if (s[0] > 0x7F) Array.append<Nat8>([0x00], s) else s;
//         let r_len = r_bytes.size();
//         let s_len = s_bytes.size();
//         let content_len = r_len + s_len + 4; // 2 for r/s tags, 2 for lengths
//         let header : [Nat8] = [0x30, Nat8.fromNat(content_len)];
//         let r_header : [Nat8] = [0x02, Nat8.fromNat(r_len)];
//         let s_header : [Nat8] = [0x02, Nat8.fromNat(s_len)];
//         let result = Array.append<Nat8>(
//             Array.append<Nat8>(
//                 Array.append<Nat8>(header, r_header),
//                 r_bytes
//             ),
//             Array.append<Nat8>(s_header, s_bytes)
//         );
//         result
//     };

//     // Helper: Convert Nat to little-endian bytes
//     private func nat_to_le_bytes(n: Nat, size: Nat) : [Nat8] {
//         let bytes = Array.init<Nat8>(size, 0);
//         var value = n;
//         var i = 0;
//         while (i < size) {
//             bytes[i] := Nat8.fromNat(value % 256);
//             value := value / 256;
//             i += 1;
//         };
//         Array.freeze(bytes)
//     };

//     // Helper: Convert Nat64 to little-endian bytes
//     private func nat64_to_le_bytes(n: Nat64) : [Nat8] {
//         let bytes = Array.init<Nat8>(8, 0);
//         var value = n;
//         var i = 0;
//         while (i < 8) {
//             bytes[i] := Nat8.fromNat(Nat64.toNat(value % 256));
//             value := value / 256;
//             i += 1;
//         };
//         Array.freeze(bytes)
//     };

//     // Test signing capability with SHA-256
//     public func test_ecdsa_signing(message: Text) : async ?Text {
//         Debug.print("🧪 Testing IC ECDSA signing capability (SHA-256)...");
        
//         try {
//             let message_blob = Sha256.fromBlob(#sha256, Text.encodeUtf8(message));
//             Debug.print("   📋 Message hash (SHA-256): " # hex_from_array(Blob.toArray(message_blob)));

//             Cycles.add<system>(30_000_000_000);
            
//             let signature_result = await management_canister.sign_with_ecdsa({
//                 message_hash = message_blob;
//                 derivation_path = [];
//                 key_id = { curve = #secp256k1; name = "dfx_test_key" };
//             });
            
//             Debug.print("   ✅ Signature generated, size: " # Nat.toText(signature_result.signature.size()));
//             Debug.print("   📋 Signature (hex): " # hex_from_array(Blob.toArray(signature_result.signature)));
            
//             ?hex_from_array(Blob.toArray(signature_result.signature))
//         } catch (err) {
//             Debug.print("   ❌ Failed to sign: " # Error.message(err));
//             null
//         };
//     };

//     // Calculate Kaspa sighash for a specific input (BLAKE2b of preimage)
//     private func calculate_sighash(
//         utxos: [UTXO],
//         inputs: [KaspaInput],
//         outputs: [KaspaOutput],
//         input_index: Nat,
//         version: Nat,
//         lockTime: Nat64,
//         subnetworkId: Text,
//         gas: Nat64,
//         payload: [Nat8],
//         sighash_type: Nat8
//     ) : [Nat8] {
//         let buf = Buffer.Buffer<Nat8>(1024);

//         // 1. Version (2 LE)
//         let version_bytes = nat_to_le_bytes(version, 2);
//         Debug.print("   🔍 Sighash: Version bytes: " # hex_from_array(version_bytes));
//         buf.append(Buffer.fromArray(version_bytes));

//         // 2. PreviousOutputsHash
//         let prevouts = Buffer.Buffer<Nat8>(0);
//         for (input in inputs.vals()) {
//             switch (hex_to_bytes(input.previousOutpoint.transactionId)) {
//                 case (?txid_bytes) prevouts.append(Buffer.fromArray(txid_bytes));
//                 case null Debug.print("   ⚠️ Invalid txid: " # input.previousOutpoint.transactionId);
//             };
//             prevouts.append(Buffer.fromArray(nat_to_le_bytes(input.previousOutpoint.index, 4)));
//         };
//         let prevouts_bytes = Buffer.toArray(prevouts);
//         Debug.print("   🔍 Sighash: Prevouts bytes: " # hex_from_array(prevouts_bytes));
//         let previousOutputsHash = Blob.toArray(Blake2b.digest(Blob.fromArray(prevouts_bytes)));
//         Debug.print("   🔍 Sighash: PreviousOutputsHash: " # hex_from_array(previousOutputsHash));
//         buf.append(Buffer.fromArray(previousOutputsHash));

//         // 3. SequencesHash
//         let seqs = Buffer.Buffer<Nat8>(0);
//         for (input in inputs.vals()) {
//             seqs.append(Buffer.fromArray(nat64_to_le_bytes(input.sequence)));
//         };
//         let seqs_bytes = Buffer.toArray(seqs);
//         Debug.print("   🔍 Sighash: Sequences bytes: " # hex_from_array(seqs_bytes));
//         let sequencesHash = Blob.toArray(Blake2b.digest(Blob.fromArray(seqs_bytes)));
//         Debug.print("   🔍 Sighash: SequencesHash: " # hex_from_array(sequencesHash));
//         buf.append(Buffer.fromArray(sequencesHash));

//         // 4. SigOpCountsHash
//         let sigops = Buffer.Buffer<Nat8>(0);
//         for (input in inputs.vals()) {
//             sigops.add(Nat8.fromNat(input.sigOpCount));
//         };
//         let sigops_bytes = Buffer.toArray(sigops);
//         Debug.print("   🔍 Sighash: SigOpCounts bytes: " # hex_from_array(sigops_bytes));
//         let sigOpCountsHash = Blob.toArray(Blake2b.digest(Blob.fromArray(sigops_bytes)));
//         Debug.print("   🔍 Sighash: SigOpCountsHash: " # hex_from_array(sigOpCountsHash));
//         buf.append(Buffer.fromArray(sigOpCountsHash));

//         // Input-specific fields
//         let input = inputs[input_index];
//         let utxo = utxos[input_index];
//         let script_version = utxo.scriptVersion;

//         // 5. PreviousOutpoint.TransactionID (32)
//         switch (hex_to_bytes(input.previousOutpoint.transactionId)) {
//             case (?txid_bytes) {
//                 Debug.print("   🔍 Sighash: TxID: " # input.previousOutpoint.transactionId);
//                 buf.append(Buffer.fromArray(txid_bytes));
//             };
//             case null Debug.print("   ⚠️ Invalid txid: " # input.previousOutpoint.transactionId);
//         };

//         // 6. PreviousOutpoint.Index (4 LE)
//         let index_bytes = nat_to_le_bytes(input.previousOutpoint.index, 4);
//         Debug.print("   🔍 Sighash: Index bytes: " # hex_from_array(index_bytes));
//         buf.append(Buffer.fromArray(index_bytes));

//         // 7. PreviousOutput.ScriptPubKeyVersion (2 LE)
//         let script_version_bytes = nat_to_le_bytes(script_version, 2);
//         Debug.print("   🔍 Sighash: Script version bytes: " # hex_from_array(script_version_bytes));
//         buf.append(Buffer.fromArray(script_version_bytes));

//         // 8-9. PreviousOutput.ScriptPubKey.length (8 LE) + ScriptPubKey
//         switch (hex_to_bytes(utxo.scriptPublicKey)) {
//             case (?script_bytes) {
//                 let script_len_bytes = nat_to_le_bytes(script_bytes.size(), 8);
//                 Debug.print("   🔍 Sighash: ScriptPubKey length: " # Nat.toText(script_bytes.size()));
//                 Debug.print("   🔍 Sighash: ScriptPubKey bytes: " # hex_from_array(script_bytes));
//                 buf.append(Buffer.fromArray(script_len_bytes));
//                 buf.append(Buffer.fromArray(script_bytes));
//             };
//             case null Debug.print("   ⚠️ Invalid scriptPublicKey: " # utxo.scriptPublicKey);
//         };

//         // 10. PreviousOutput.Value (8 LE)
//         let amount_bytes = nat64_to_le_bytes(utxo.amount);
//         Debug.print("   🔍 Sighash: Amount bytes: " # hex_from_array(amount_bytes));
//         buf.append(Buffer.fromArray(amount_bytes));

//         // 11. Sequence (8 LE)
//         let sequence_bytes = nat64_to_le_bytes(input.sequence);
//         Debug.print("   🔍 Sighash: Sequence bytes: " # hex_from_array(sequence_bytes));
//         buf.append(Buffer.fromArray(sequence_bytes));

//         // 12. SigOpCount (1)
//         let sigop_count_byte = [Nat8.fromNat(input.sigOpCount)];
//         Debug.print("   🔍 Sighash: SigOpCount byte: " # hex_from_array(sigop_count_byte));
//         buf.add(Nat8.fromNat(input.sigOpCount));

//         // 13. OutputsHash
//         let outs = Buffer.Buffer<Nat8>(0);
//         for (output in outputs.vals()) {
//             let output_amount_bytes = nat64_to_le_bytes(output.amount);
//             let output_script_version_bytes = nat_to_le_bytes(output.scriptPublicKey.version, 2);
//             outs.append(Buffer.fromArray(output_amount_bytes));
//             outs.append(Buffer.fromArray(output_script_version_bytes));
//             switch (hex_to_bytes(output.scriptPublicKey.scriptPublicKey)) {
//                 case (?script_bytes) {
//                     let script_len_bytes = nat_to_le_bytes(script_bytes.size(), 8);
//                     outs.append(Buffer.fromArray(script_len_bytes));
//                     outs.append(Buffer.fromArray(script_bytes));
//                 };
//                 case null Debug.print("   ⚠️ Invalid output scriptPublicKey: " # output.scriptPublicKey.scriptPublicKey);
//             };
//         };
//         let outs_bytes = Buffer.toArray(outs);
//         Debug.print("   🔍 Sighash: Outputs bytes: " # hex_from_array(outs_bytes));
//         let outputsHash = Blob.toArray(Blake2b.digest(Blob.fromArray(outs_bytes)));
//         Debug.print("   🔍 Sighash: OutputsHash: " # hex_from_array(outputsHash));
//         buf.append(Buffer.fromArray(outputsHash));

//         // 14. Locktime (8 LE)
//         let locktime_bytes = nat64_to_le_bytes(lockTime);
//         Debug.print("   🔍 Sighash: Locktime bytes: " # hex_from_array(locktime_bytes));
//         buf.append(Buffer.fromArray(locktime_bytes));

//         // 15. SubnetworkID (20)
//         switch (hex_to_bytes(subnetworkId)) {
//             case (?sub_bytes) {
//                 Debug.print("   🔍 Sighash: SubnetworkID bytes: " # hex_from_array(sub_bytes));
//                 buf.append(Buffer.fromArray(sub_bytes));
//             };
//             case null Debug.print("   ⚠️ Invalid subnetworkId: " # subnetworkId);
//         };

//         // 16. Gas (8 LE)
//         let gas_bytes = nat64_to_le_bytes(gas);
//         Debug.print("   🔍 Sighash: Gas bytes: " # hex_from_array(gas_bytes));
//         buf.append(Buffer.fromArray(gas_bytes));

//         // 17. PayloadHash (32)
//         let payloadHash = Blob.toArray(Blake2b.digest(Blob.fromArray(payload)));
//         Debug.print("   🔍 Sighash: PayloadHash: " # hex_from_array(payloadHash));
//         buf.append(Buffer.fromArray(payloadHash));

//         // 18. SigHash type (1)
//         Debug.print("   🔍 Sighash: Sighash type: " # hex_from_array([sighash_type]));
//         buf.add(sighash_type);

//         let final_preimage = Buffer.toArray(buf);
//         Debug.print("   🔍 Sighash: Final preimage: " # hex_from_array(final_preimage));
//         let sighash = Blob.toArray(Blake2b.digest(Blob.fromArray(final_preimage)));
//         Debug.print("   🔍 Sighash: Final hash: " # hex_from_array(sighash));
//         sighash
//     };

//     // Sign a transaction input
//     private func sign_transaction_input(
//         utxos: [UTXO],
//         inputs: [KaspaInput],
//         outputs: [KaspaOutput],
//         input_index: Nat,
//         version: Nat,
//         lockTime: Nat64,
//         subnetworkId: Text,
//         gas: Nat64,
//         payload: [Nat8],
//         sighash_type: Nat8,
//         derivation_path: Text
//     ) : async ?Text {
//         try {
//             let sighash = calculate_sighash(
//                 utxos,
//                 inputs,
//                 outputs,
//                 input_index,
//                 version,
//                 lockTime,
//                 subnetworkId,
//                 gas,
//                 payload,
//                 sighash_type
//             );

//             Debug.print("   🔢 Sighash for input " # Nat.toText(input_index) # ": " # hex_from_array(sighash));
//             Debug.print("   🔑 Derivation path: " # derivation_path # " -> " # 
//                 Text.join(",", Iter.map<Blob, Text>(text_to_derivation_path(derivation_path).vals(), func(b) = hex_from_array(Blob.toArray(b)))));

//             // Workaround: Double-hash with SHA-256 for compatibility
//             let sha256_sighash = Sha256.fromBlob(#sha256, Blob.fromArray(sighash));
//             Debug.print("   🔢 SHA-256(BLAKE2b) hash: " # hex_from_array(Blob.toArray(sha256_sighash)));

//             Cycles.add<system>(30_000_000_000);
            
//             let signature_result = await management_canister.sign_with_ecdsa({
//                 message_hash = sha256_sighash;
//                 derivation_path = text_to_derivation_path(derivation_path);
//                 key_id = { curve = #secp256k1; name = "dfx_test_key" };
//             });
            
//             Debug.print("   ✅ Signature received: " # hex_from_array(Blob.toArray(signature_result.signature)));
            
//             let raw_sig = Blob.toArray(signature_result.signature);
//             let der_sig = der_encode_signature(raw_sig);
//             let sig_bytes = Array.append<Nat8>(der_sig, [0x01]); // SIGHASH_ALL

//             let sig_len = Nat8.fromNat(sig_bytes.size());
//             let sig_hex = hex_from_array(sig_bytes);
//             let script_hex = hex_from_array([sig_len]) # sig_hex; // P2PK: push <DER sig + type>

//             ?script_hex
//         } catch (e) {
//             Debug.print("Error signing input: " # Error.message(e));
//             null
//         };
//     };

//     // Generate a Kaspa address and scriptPublicKey
//     public func generate_address_with_script(derivation_path: Text) : async {address: Text; scriptPublicKey: Text; publicKey: Text} {
//         try {
//             Cycles.add<system>(30_000_000_000);
            
//             Debug.print("   🔑 Generating address for derivation path: " # derivation_path # " -> " # 
//                 Text.join(",", Iter.map<Blob, Text>(text_to_derivation_path(derivation_path).vals(), func(b) = hex_from_array(Blob.toArray(b)))));

//             let result = await management_canister.ecdsa_public_key({
//                 canister_id = null;
//                 derivation_path = text_to_derivation_path(derivation_path);
//                 key_id = { curve = #secp256k1; name = "dfx_test_key" };
//             });
            
//             let compressed_key_opt = to_compressed_public_key(result.public_key);
//             switch (compressed_key_opt) {
//                 case (null) {
//                     { address = ""; scriptPublicKey = ""; publicKey = "" }
//                 };
//                 case (?compressed_key) {
//                     let pub_key_hex = hex_from_array(Blob.toArray(compressed_key));
//                     let script_hex = "21" # pub_key_hex # "ac"; // P2PK: OP_DATA_33 <pubkey> OP_CHECKSIG
//                     let kaspa_address = Address.address_from_pubkey(compressed_key, Address.ECDSA);
                    
//                     { 
//                         address = kaspa_address; 
//                         scriptPublicKey = script_hex;
//                         publicKey = pub_key_hex;
//                     }
//                 };
//             };
//         } catch (e) {
//             Debug.print("Error generating address: " # Error.message(e));
//             { address = ""; scriptPublicKey = ""; publicKey = "" }
//         };
//     };

//     // Convert TransactionRequest to JSON string for API submission
//     private func transaction_request_to_json(request: TransactionRequest) : Text {
//         let tx = request.transaction;
//         var json = "{\"transaction\":{";
//         json #= "\"version\":" # Nat.toText(tx.version) # ",";
//         json #= "\"inputs\":[";
//         var first_input = true;
//         for (input in tx.inputs.vals()) {
//             if (not first_input) { json #= ","; };
//             json #= "{";
//             json #= "\"previousOutpoint\":{";
//             json #= "\"transactionId\":\"" # input.previousOutpoint.transactionId # "\",";
//             json #= "\"index\":" # Nat.toText(input.previousOutpoint.index);
//             json #= "},";
//             json #= "\"signatureScript\":\"" # input.signatureScript # "\",";
//             json #= "\"sequence\":" # Nat64.toText(input.sequence) # ",";
//             json #= "\"sigOpCount\":" # Nat.toText(input.sigOpCount);
//             json #= "}";
//             first_input := false;
//         };
//         json #= "],";
//         json #= "\"outputs\":[";
//         var first_output = true;
//         for (output in tx.outputs.vals()) {
//             if (not first_output) { json #= ","; };
//             json #= "{";
//             json #= "\"amount\":" # Nat64.toText(output.amount) # ",";
//             json #= "\"scriptPublicKey\":{";
//             json #= "\"version\":" # Nat.toText(output.scriptPublicKey.version) # ",";
//             json #= "\"scriptPublicKey\":\"" # output.scriptPublicKey.scriptPublicKey # "\"";
//             json #= "}";
//             json #= "}";
//             first_output := false;
//         };
//         json #= "],";
//         json #= "\"lockTime\":" # Nat64.toText(tx.lockTime) # ",";
//         json #= "\"subnetworkId\":\"" # tx.subnetworkId # "\",";
//         json #= "\"gas\":" # Nat64.toText(tx.gas) # ",";
//         json #= "\"payload\":\"" # hex_from_array(tx.payload) # "\"";
//         json #= "},\"allowOrphan\":" # (if (request.allowOrphan) "true" else "false") # "}";
//         json
//     };

//     // Build and sign a transaction
//     public func build_transaction(
//         utxos: [UTXO],
//         to_scriptPublicKey: Text, // recipient scriptPublicKey hex
//         amount: Nat64,
//         fee: Nat64,
//         change_derivation_path: Text
//     ) : async Result.Result<TransactionRequest, Text> {
//         Debug.print("🏗️ Building Kaspa transaction...");
//         Debug.print("   📊 UTXOs: " # Nat.toText(utxos.size()));
//         Debug.print("   💰 Amount: " # Nat64.toText(amount) # " sompi");
//         Debug.print("   💸 Fee: " # Nat64.toText(fee) # " sompi");
        
//         // Validate inputs
//         if (utxos.size() == 0) {
//             return #err("No UTXOs provided");
//         };
        
//         // Calculate total input amount
//         var total_input : Nat64 = 0;
//         for (utxo in utxos.vals()) {
//             total_input += utxo.amount;
//         };
        
//         if (total_input < amount + fee) {
//             return #err("Insufficient funds: need " # Nat64.toText(amount + fee) # ", have " # Nat64.toText(total_input));
//         };
        
//         let change_amount = total_input - amount - fee;
//         Debug.print("   🔄 Change: " # Nat64.toText(change_amount) # " sompi");
        
//         try {
//             // Generate change address
//             let change_info = await generate_address_with_script(change_derivation_path);
//             if (change_info.address == "") {
//                 return #err("Failed to generate change address");
//             };
            
//             // Build outputs
//             let outputs_buffer = Buffer.Buffer<KaspaOutput>(2);
            
//             // Recipient output
//             outputs_buffer.add({
//                 amount = amount;
//                 scriptPublicKey = {
//                     version = 0;
//                     scriptPublicKey = to_scriptPublicKey;
//                 };
//             });
            
//             // Change output
//             if (change_amount > 0) {
//                 outputs_buffer.add({
//                     amount = change_amount;
//                     scriptPublicKey = {
//                         version = 0;
//                         scriptPublicKey = change_info.scriptPublicKey;
//                     };
//                 });
//             };
            
//             let outputs = Buffer.toArray(outputs_buffer);
            
//             // Build unsigned inputs
//             let inputs_buffer = Buffer.Buffer<KaspaInput>(utxos.size());
//             for (utxo in utxos.vals()) {
//                 inputs_buffer.add({
//                     previousOutpoint = {
//                         transactionId = utxo.transactionId;
//                         index = utxo.index;
//                     };
//                     signatureScript = "";
//                     sequence = 0xffffffffffffffff;
//                     sigOpCount = 1;
//                 });
//             };
            
//             let inputs = Buffer.toArray(inputs_buffer);
            
//             // Sign each input
//             let signed_inputs_buffer = Buffer.Buffer<KaspaInput>(inputs.size());
//             for (i in Iter.range(0, inputs.size() - 1)) {
//                 let input = inputs[i];
                
//                 let signature_script_opt = await sign_transaction_input(
//                     utxos,
//                     inputs,
//                     outputs,
//                     i,
//                     0, // version
//                     0, // lockTime
//                     "0000000000000000000000000000000000000000", // subnetworkId
//                     0, // gas
//                     [], // payload
//                     0x01, // SIGHASH_ALL
//                     "sender" // Use sender derivation path for input
//                 );
                
//                 switch (signature_script_opt) {
//                     case (null) {
//                         return #err("Failed to sign input " # Nat.toText(i));
//                     };
//                     case (?sig_script) {
//                         signed_inputs_buffer.add({
//                             previousOutpoint = input.previousOutpoint;
//                             signatureScript = sig_script;
//                             sequence = input.sequence;
//                             sigOpCount = input.sigOpCount;
//                         });
//                         Debug.print("   ✅ Signed input " # Nat.toText(i));
//                     };
//                 };
//             };
            
//             let signed_inputs = Buffer.toArray(signed_inputs_buffer);
            
//             let transaction : KaspaTransaction = {
//                 version = 0;
//                 inputs = signed_inputs;
//                 outputs = outputs;
//                 lockTime = 0;
//                 subnetworkId = "0000000000000000000000000000000000000000";
//                 gas = 0;
//                 payload = [];
//             };
            
//             let request : TransactionRequest = {
//                 transaction = transaction;
//                 allowOrphan = false;
//             };
            
//             Debug.print("   🎉 Transaction built and signed successfully!");
//             #ok(request)
            
//         } catch (e) {
//             #err("Transaction building failed: " # Error.message(e))
//         };
//     };

//     // Test function with real UTXO and recipient
//     public func test_transaction_building() : async () {
//         Debug.print("\n🧪 === TESTING TRANSACTION BUILDING ===");
        
//         // Real UTXO from API
//         let utxos : [UTXO] = [{
//             transactionId = "1e082841b49cd9aaf847388371a227561bd715dc79805a519f059b65a668f124";
//             index = 0;
//             amount = 100000000; // 1 KAS
//             scriptPublicKey = "2102219f48df455684794a1a20f8bfc3904365ce55a42d8a1c44541480ba4ed71f61ac"; // Corrected to ac
//             scriptVersion = 0; // Default
//             address = "kaspa:qypzr86gmaz4dprefgdzp79lcwgyxeww2kjzmzsug32pfq96fmt37cg65e4up0j";
//         }];

//         // Recipient scriptPublicKey for kaspa:qqqfnefs... from 96df4fa1... output #0
//         let recipient_scriptPublicKey = "200099e53094a3fbe8df4fd0db8f92d85f50c3802ede184706de990c46fcdcc503ac";

//         let amount = Nat64.fromNat(10000000); // 0.1 KAS
//         let fee = Nat64.fromNat(10000); // 0.0001 KAS
//         let derivation_path = "sender"; // For funded address
//         let change_derivation_path = "change";

//         // Cache change address to stabilize sighash
//         let change_info = await generate_address_with_script(change_derivation_path);
//         if (change_info.address == "") {
//             Debug.print("   ❌ Failed to generate change address");
//             return;
//         };
//         Debug.print("   📫 Cached change address: " # change_info.address);
//         Debug.print("   📫 Cached change scriptPublicKey: " # change_info.scriptPublicKey);

//         Debug.print("   📫 Sender: " # utxos[0].address);
//         Debug.print("   📫 Recipient: kaspa:qqqfnefsjj3lh6xlflgdhrujmp04psuq9m0ps3cxm6vsc3humnzsxrdcg8dc4");
//         Debug.print("   💰 Sending: " # Nat64.toText(amount) # " sompi");
//         Debug.print("   💸 Fee: " # Nat64.toText(fee) # " sompi");
        
//         let result = await build_transaction(
//             utxos,
//             recipient_scriptPublicKey,
//             amount,
//             fee,
//             change_derivation_path
//         );
        
//         switch (result) {
//             case (#err(msg)) {
//                 Debug.print("   ❌ Transaction failed: " # msg);
//             };
//             case (#ok(tx_request)) {
//                 Debug.print("   ✅ Transaction created successfully!");
//                 Debug.print("   📋 Inputs: " # Nat.toText(tx_request.transaction.inputs.size()));
//                 Debug.print("   📋 Outputs: " # Nat.toText(tx_request.transaction.outputs.size()));
//                 Debug.print("   📋 Total outputs value: " # 
//                     Nat64.toText(Array.foldLeft<KaspaOutput, Nat64>(
//                         tx_request.transaction.outputs, 0, 
//                         func(acc, output) = acc + output.amount
//                     )) # " sompi");
//                 let json = transaction_request_to_json(tx_request);
//                 Debug.print("   📤 JSON for submission: " # json);
//             };
//         };
        
//         Debug.print("\n💡 Next steps:");
//         Debug.print("1. POST JSON to https://api.kaspa.org/transactions");
//         Debug.print("2. Monitor tx status at https://explorer.kaspa.org");
//     };
// };