import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Nat8 "mo:base/Nat8";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Char "mo:base/Char";

import Address "../kaspa/address";
import PersonalMessage "../kaspa/personal_message";

persistent actor KaspaTester {
    
    // Address type constants (matching your Address.mo)
    private let SCHNORR : Nat = 0;
    private let ECDSA : Nat = 1;
    private let P2SH : Nat = 2;
    
    // Address length constants
    private let SCHNORR_ADDRESS_LEN : Nat = 64;
    private let ECDSA_ADDRESS_LEN : Nat = 65;
    
    // Types for better organization
    public type AddressInfo = {
        address: Text;
        address_type: Text;
        success: Bool;
    };
    
    // Simple hex conversion functions
    private func hexCharToNat8(c: Char) : ?Nat8 {
        switch (c) {
            case '0' ?0;
            case '1' ?1;
            case '2' ?2;
            case '3' ?3;
            case '4' ?4;
            case '5' ?5;
            case '6' ?6;
            case '7' ?7;
            case '8' ?8;
            case '9' ?9;
            case 'a' ?10;
            case 'A' ?10;
            case 'b' ?11;
            case 'B' ?11;
            case 'c' ?12;
            case 'C' ?12;
            case 'd' ?13;
            case 'D' ?13;
            case 'e' ?14;
            case 'E' ?14;
            case 'f' ?15;
            case 'F' ?15;
            case _ null;
        }
    };
    
    private func hexStringToBytes(hex: Text) : ?[Nat8] {
        let chars = Text.toArray(hex);
        if (chars.size() % 2 != 0) return null;
        
        let bytes = Array.init<Nat8>(chars.size() / 2, 0);
        var i = 0;
        while (i < chars.size()) {
            switch (hexCharToNat8(chars[i]), hexCharToNat8(chars[i + 1])) {
                case (?high, ?low) {
                    bytes[i / 2] := high * 16 + low;
                };
                case _ return null;
            };
            i += 2;
        };
        ?Array.freeze(bytes)
    };
    
    private func bytesToHexString(bytes: [Nat8]) : Text {
        let hexChars = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'];
        var result = "";
        for (byte in bytes.vals()) {
            let high = byte / 16;
            let low = byte % 16;
            result #= Char.toText(hexChars[Nat8.toNat(high)]);
            result #= Char.toText(hexChars[Nat8.toNat(low)]);
        };
        result
    };
    
    // Test address generation from a hex public key
    public func testAddressFromPublicKey(publicKeyHex: Text, addressType: Nat) : async AddressInfo {
        Debug.print("Testing address from public key: " # publicKeyHex);
        Debug.print("Address type: " # debug_show(addressType));
        
        switch (hexStringToBytes(publicKeyHex)) {
            case (null) {
                Debug.print("Invalid hex format");
                {
                    address = "";
                    address_type = "ERROR";
                    success = false;
                }
            };
            case (?bytes) {
                let publicKey = Blob.fromArray(bytes);
                Debug.print("Public key bytes length: " # debug_show(bytes.size()));
                
                let addressTypeText = switch (addressType) {
                    case (0) "SCHNORR";
                    case (1) "ECDSA";
                    case (2) "P2SH";
                    case (_) "UNKNOWN";
                };
                
                let addressLen = if (addressType == 1) ECDSA_ADDRESS_LEN else SCHNORR_ADDRESS_LEN;
                let address = Address.address_from_pubkey(publicKey, addressType, addressLen);
                
                Debug.print("Generated address: " # address);
                
                {
                    address = address;
                    address_type = addressTypeText;
                    success = address != "";
                }
            };
        }
    };
    
    // Test with byte arrays directly (easier for Candid UI)
    public func testAddressFromBytes(publicKeyBytes: [Nat8], addressType: Nat) : async AddressInfo {
        Debug.print("Testing address from bytes, length: " # debug_show(publicKeyBytes.size()));
        Debug.print("Address type: " # debug_show(addressType));
        
        let publicKey = Blob.fromArray(publicKeyBytes);
        
        let addressTypeText = switch (addressType) {
            case (0) "SCHNORR";
            case (1) "ECDSA"; 
            case (2) "P2SH";
            case (_) "UNKNOWN";
        };
        
        let addressLen = if (addressType == 1) ECDSA_ADDRESS_LEN else SCHNORR_ADDRESS_LEN;
        let address = Address.address_from_pubkey(publicKey, addressType, addressLen);
        
        Debug.print("Generated address: " # address);
        
        {
            address = address;
            address_type = addressTypeText;
            success = address != "";
        }
    };
    
    // Test message hashing
    public func testMessageHashing(message: Text) : async {
        message: Text;
        hash_hex: Text;
        success: Bool;
    } {
        Debug.print("Hashing message: " # message);
        
        let messageBytes = Blob.toArray(Text.encodeUtf8(message));
        let outHash = Array.init<Nat8>(32, 0);
        
        let success = PersonalMessage.hash_personal_message(messageBytes, messageBytes.size(), outHash);
        let hashBytes = Array.freeze(outHash);
        
        {
            message = message;
            hash_hex = if (success) bytesToHexString(hashBytes) else "";
            success = success;
        }
    };
    
    // Run tests with known good data
    public func runKnownTests() : async Text {
        Debug.print("=== Running Known Tests ===");
        var results = "";
        
        // Test 1: ECDSA address - using explicit Nat8 literals
        let ecdsaPubKeyBytes : [Nat8] = [
            213, 253, 199, 173, 17, 166, 93, 11, 190, 120, 130, 252, 61, 188, 145, 181,
            134, 29, 24, 45, 204, 231, 159, 124, 27, 229, 191, 211, 10, 103, 124, 214,
            197, 98, 173, 102, 171, 205, 177, 236, 2, 243, 228, 176, 124, 17, 188, 90,
            148, 166, 133, 254, 219, 93, 85, 135, 7, 110, 72, 177, 45, 166, 194, 130
        ];
        let expectedEcdsaAddress = "kaspa:qypdtlw845g6vhgtheug9lpahjgmtpsarqkueeul0sd7t07npfnhe4s7fd82n0v";
        
        let ecdsaResult = await testAddressFromBytes(ecdsaPubKeyBytes, ECDSA);
        let ecdsaPass = ecdsaResult.address == expectedEcdsaAddress;
        results #= "ECDSA Test: " # (if (ecdsaPass) "PASS" else "FAIL") # "\n";
        results #= "  Expected: " # expectedEcdsaAddress # "\n";
        results #= "  Got:      " # ecdsaResult.address # "\n\n";
        
        // Test 2: Schnorr address - using explicit Nat8 literals
        let schnorrPubKeyBytes : [Nat8] = [
            33, 235, 12, 66, 112, 18, 139, 22, 201, 60, 95, 13, 172, 72, 213, 96,
            81, 166, 35, 125, 174, 153, 123, 88, 145, 38, 149, 5, 40, 24, 227, 72,
            176, 168, 149, 203, 208, 201, 58, 17, 238, 122, 250, 199, 69, 146, 157, 150,
            164, 100, 42, 113, 131, 31, 84, 167, 55, 120, 147, 175, 113, 162, 226, 174
        ];
        let expectedSchnorrAddress = "kaspa:qqs7krzzwqfgk9kf830smtzg64s9rf3r0khfj76cjynf2pfgrr35saatu88xq";
        
        let schnorrResult = await testAddressFromBytes(schnorrPubKeyBytes, SCHNORR);
        let schnorrPass = schnorrResult.address == expectedSchnorrAddress;
        results #= "Schnorr Test: " # (if (schnorrPass) "PASS" else "FAIL") # "\n";
        results #= "  Expected: " # expectedSchnorrAddress # "\n";
        results #= "  Got:      " # schnorrResult.address # "\n\n";
        
        // Test 3: Message hashing
        let hashResult = await testMessageHashing("Hello Kaspa!");
        let expectedHash = "2e55deda4a5224208dbd4d93cfe5aa22d945eaa63172e329c49afed62f0e1510";
        let hashPass = hashResult.hash_hex == expectedHash;
        results #= "Message Hash Test: " # (if (hashPass) "PASS" else "FAIL") # "\n";
        results #= "  Expected: " # expectedHash # "\n";
        results #= "  Got:      " # hashResult.hash_hex # "\n\n";
        
        let allPass = ecdsaPass and schnorrPass and hashPass;
        results #= "=== OVERALL: " # (if (allPass) "ALL TESTS PASSED" else "SOME TESTS FAILED") # " ===";
        
        results
    };
    
    // Simple validation
    public func validateKaspaAddress(address: Text) : async Bool {
        Text.startsWith(address, #text("kaspa:")) and address.size() > 6
    };
}