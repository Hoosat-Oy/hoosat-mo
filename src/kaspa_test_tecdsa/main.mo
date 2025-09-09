import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Nat8 "mo:base/Nat8";
import Nat "mo:base/Nat";
import Cycles "mo:base/ExperimentalCycles";
import Error "mo:base/Error";
import Principal "mo:base/Principal";

import Sha256 "mo:sha2/Sha256";


import Address "../kaspa/address";

persistent actor KaspaTestTecdsa {

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

    // Helper: Convert to compressed format if needed
    private func to_compressed_public_key(public_key: Blob) : ?Blob {
        let key_bytes = Blob.toArray(public_key);
        
        if (key_bytes.size() == 33 and (key_bytes[0] == 0x02 or key_bytes[0] == 0x03)) {
            // Already compressed
            ?public_key
        } else if (key_bytes.size() == 65 and key_bytes[0] == 0x04) {
            // Uncompressed - convert to compressed
            let x_bytes = Array.subArray<Nat8>(key_bytes, 1, 32);
            let y_bytes = Array.subArray<Nat8>(key_bytes, 33, 32);
            
            // Determine compression prefix based on y coordinate parity
            let y_is_even = (y_bytes[31] % 2) == 0;
            let prefix : Nat8 = if (y_is_even) 0x02 else 0x03;
            
            let compressed = Array.append<Nat8>([prefix], x_bytes);
            ?Blob.fromArray(compressed)
        } else {
            // Unknown format
            null
        }
    };

    // Helper: Convert array to hex for debugging
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

    // Updated test for ECDSA address from IC ECDSA public key
    public func test_ecdsa_address_from_ic_public_key() : async () {
        Debug.print("🧪 Testing ECDSA address generation from IC ECDSA public key...");
        
        try {
            Debug.print("   Adding cycles for ecdsa_public_key call...");
            Cycles.add<system>(30_000_000_000);
            
            let result = await management_canister.ecdsa_public_key({
                canister_id = null;
                derivation_path = []; // Root key for testing
                key_id = { curve = #secp256k1; name = "dfx_test_key" };
            });
            
            Debug.print("   Received public key, size: " # Nat.toText(result.public_key.size()));
            Debug.print("   Raw public key (hex): " # hex_from_array(Blob.toArray(result.public_key)));
            
            let compressed_key_opt = to_compressed_public_key(result.public_key);
            switch (compressed_key_opt) {
                case (null) {
                    Debug.print("   ❌ Failed to process public key: invalid format");
                    assert false;
                };
                case (?compressed_key) {
                    let key_bytes = Blob.toArray(compressed_key);
                    Debug.print("   ✅ Compressed public key size: " # Nat.toText(key_bytes.size()));
                    Debug.print("   📋 Compressed public key (hex): " # hex_from_array(key_bytes));
                    Debug.print("   📋 First byte (compression): 0x" # hex_from_array([key_bytes[0]]));
                    
                    // Verify it's the right format for Kaspa ECDSA
                    assert key_bytes.size() == Address.ECDSA_PAYLOAD_LEN; // 33 bytes
                    assert key_bytes[0] == 0x02 or key_bytes[0] == 0x03; // Compressed format
                    
                    // Generate Kaspa address
                    let kaspa_address = Address.address_from_pubkey(compressed_key, Address.ECDSA);
                    Debug.print("   🏠 Generated Kaspa address: " # kaspa_address);
                    
                    // Verify address format
                    assert kaspa_address.size() > 0;
                    assert Text.startsWith(kaspa_address, #text("kaspa:"));
                    
                    Debug.print("   ✅ IC ECDSA → Kaspa address generation successful!");
                    
                    // Print verification instructions
                    Debug.print("   🔍 VERIFICATION STEPS:");
                    Debug.print("   1. Public Key: " # hex_from_array(key_bytes));
                    Debug.print("   2. Kaspa Address: " # kaspa_address);
                    Debug.print("   3. Verify this public key generates the same address externally");
                    Debug.print("   4. Test with small transaction to this address");
                };
            };
        } catch (err) {
            Debug.print("   ❌ Failed to get IC ECDSA public key: " # Error.message(err));
            assert false;
        };
    };

    // Test with derivation path (for multiple addresses)
    public func test_ecdsa_with_derivation_path(path_text: Text) : async Text {
        Debug.print("🧪 Testing ECDSA with derivation path: " # path_text);
        
        try {
            Cycles.add<system>(30_000_000_000);
            
            let derivation_path = [Text.encodeUtf8(path_text)];
            let result = await management_canister.ecdsa_public_key({
                canister_id = null;
                derivation_path = derivation_path;
                key_id = { curve = #secp256k1; name = "dfx_test_key" };
            });
            
            let compressed_key_opt = to_compressed_public_key(result.public_key);
            switch (compressed_key_opt) {
                case (null) {
                    Debug.print("   ❌ Failed to process public key");
                    ""
                };
                case (?compressed_key) {
                    let kaspa_address = Address.address_from_pubkey(compressed_key, Address.ECDSA);
                    Debug.print("   📍 Path '" # path_text # "' → Address: " # kaspa_address);
                    kaspa_address
                };
            };
        } catch (err) {
            Debug.print("   ❌ Error with derivation path: " # Error.message(err));
            ""
        };
    };

    // Test signing capability (for future transaction signing)
    public func test_ecdsa_signing(message: Text) : async ?Blob {
        Debug.print("🧪 Testing IC ECDSA signing capability...");
        
        try {
            // Create a test message hash (in production, this would be a transaction hash)
            //let message_blob = Text.encodeUtf8(message);
            let message_blob = Sha256.fromBlob(#sha256, Text.encodeUtf8(message));

            Cycles.add<system>(30_000_000_000);
            
            let signature_result = await management_canister.sign_with_ecdsa({
                message_hash = message_blob;
                derivation_path = [];
                key_id = { curve = #secp256k1; name = "dfx_test_key" };
            });
            
            Debug.print("   ✅ Signature generated, size: " # Nat.toText(signature_result.signature.size()));
            Debug.print("   📋 Signature (hex): " # hex_from_array(Blob.toArray(signature_result.signature)));
            
            ?signature_result.signature
        } catch (err) {
            Debug.print("   ❌ Failed to sign: " # Error.message(err));
            null
        };
    };

    // Comprehensive test combining all functionality
    public func run_comprehensive_ic_kaspa_test() : async () {
        Debug.print("\n🚀 === COMPREHENSIVE IC ECDSA + KASPA TEST ===");
        
        // Test 1: Basic address generation
        await test_ecdsa_address_from_ic_public_key();
        
        // Test 2: Multiple addresses with derivation paths
        let addr1 = await test_ecdsa_with_derivation_path("kaspa-wallet-1");
        let addr2 = await test_ecdsa_with_derivation_path("kaspa-wallet-2");
        let addr3 = await test_ecdsa_with_derivation_path("kaspa-transaction-123");
        
        Debug.print("\n📍 Generated addresses:");
        Debug.print("   Wallet 1: " # addr1);
        Debug.print("   Wallet 2: " # addr2);
        Debug.print("   Transaction: " # addr3);
        
        // Test 3: Signing capability
        let signature_opt = await test_ecdsa_signing("Hello Kaspa from IC!");
        switch (signature_opt) {
            case (null) Debug.print("   ⚠️  Signing test failed");
            case (?_) Debug.print("   ✅ Signing test successful");
        };
        
        Debug.print("\n💡 NEXT VERIFICATION STEPS:");
        Debug.print("1. Copy the public keys and verify with external secp256k1 tools");
        Debug.print("2. Send small amounts to the generated addresses");
        Debug.print("3. Test transaction signing and broadcasting");
        Debug.print("4. Verify signatures are accepted by Kaspa network");
        
        Debug.print("\n🎉 IC ECDSA + Kaspa integration test completed!");
    };
};