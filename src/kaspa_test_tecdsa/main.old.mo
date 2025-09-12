// import Debug "mo:base/Debug";
// import Blob "mo:base/Blob";
// import Array "mo:base/Array";
// import Text "mo:base/Text";
// import Nat8 "mo:base/Nat8";
// import Nat "mo:base/Nat";
// import Cycles "mo:base/ExperimentalCycles";
// import Error "mo:base/Error";
// import Principal "mo:base/Principal";

// import Sha256 "mo:sha2/Sha256";
// import Blake2b "mo:blake2b";


// import Address "../kaspa/address";

// persistent actor KaspaTestTecdsa {

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

//     // Helper: Convert to compressed format if needed
//     private func to_compressed_public_key(public_key: Blob) : ?Blob {
//         let key_bytes = Blob.toArray(public_key);
        
//         if (key_bytes.size() == 33 and (key_bytes[0] == 0x02 or key_bytes[0] == 0x03)) {
//             // Already compressed
//             ?public_key
//         } else if (key_bytes.size() == 65 and key_bytes[0] == 0x04) {
//             // Uncompressed - convert to compressed
//             let x_bytes = Array.subArray<Nat8>(key_bytes, 1, 32);
//             let y_bytes = Array.subArray<Nat8>(key_bytes, 33, 32);
            
//             // Determine compression prefix based on y coordinate parity
//             let y_is_even = (y_bytes[31] % 2) == 0;
//             let prefix : Nat8 = if (y_is_even) 0x02 else 0x03;
            
//             let compressed = Array.append<Nat8>([prefix], x_bytes);
//             ?Blob.fromArray(compressed)
//         } else {
//             // Unknown format
//             null
//         }
//     };

//     // Helper: Convert array to hex for debugging
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

//     // Updated test for ECDSA address from IC ECDSA public key
//     public func test_ecdsa_address_from_ic_public_key() : async () {
//         Debug.print("🧪 Testing ECDSA address generation from IC ECDSA public key...");
        
//         try {
//             Debug.print("   Adding cycles for ecdsa_public_key call...");
//             Cycles.add<system>(30_000_000_000);
            
//             let result = await management_canister.ecdsa_public_key({
//                 canister_id = null;
//                 derivation_path = []; // Root key for testing
//                 key_id = { curve = #secp256k1; name = "dfx_test_key" };
//             });
            
//             Debug.print("   Received public key, size: " # Nat.toText(result.public_key.size()));
//             Debug.print("   Raw public key (hex): " # hex_from_array(Blob.toArray(result.public_key)));
            
//             let compressed_key_opt = to_compressed_public_key(result.public_key);
//             switch (compressed_key_opt) {
//                 case (null) {
//                     Debug.print("   ❌ Failed to process public key: invalid format");
//                     assert false;
//                 };
//                 case (?compressed_key) {
//                     let key_bytes = Blob.toArray(compressed_key);
//                     Debug.print("   ✅ Compressed public key size: " # Nat.toText(key_bytes.size()));
//                     Debug.print("   📋 Compressed public key (hex): " # hex_from_array(key_bytes));
//                     Debug.print("   📋 First byte (compression): 0x" # hex_from_array([key_bytes[0]]));
                    
//                     // Verify it's the right format for Kaspa ECDSA
//                     assert key_bytes.size() == Address.ECDSA_PAYLOAD_LEN; // 33 bytes
//                     assert key_bytes[0] == 0x02 or key_bytes[0] == 0x03; // Compressed format
                    
//                     // Generate Kaspa address
//                     let kaspa_address = Address.address_from_pubkey(compressed_key, Address.ECDSA);
//                     Debug.print("   🏠 Generated Kaspa address: " # kaspa_address);
                    
//                     // Verify address format
//                     assert kaspa_address.size() > 0;
//                     assert Text.startsWith(kaspa_address, #text("kaspa:"));
                    
//                     Debug.print("   ✅ IC ECDSA → Kaspa address generation successful!");
                    
//                     // Print verification instructions
//                     Debug.print("   🔍 VERIFICATION STEPS:");
//                     Debug.print("   1. Public Key: " # hex_from_array(key_bytes));
//                     Debug.print("   2. Kaspa Address: " # kaspa_address);
//                     Debug.print("   3. Verify this public key generates the same address externally");
//                     Debug.print("   4. Test with small transaction to this address");
//                 };
//             };
//         } catch (err) {
//             Debug.print("   ❌ Failed to get IC ECDSA public key: " # Error.message(err));
//             assert false;
//         };
//     };

//     // Test with derivation path (for multiple addresses)
//     public func test_ecdsa_with_derivation_path(path_text: Text) : async Text {
//         Debug.print("🧪 Testing ECDSA with derivation path: " # path_text);
        
//         try {
//             Cycles.add<system>(30_000_000_000);
            
//             let derivation_path = [Text.encodeUtf8(path_text)];
//             let result = await management_canister.ecdsa_public_key({
//                 canister_id = null;
//                 derivation_path = derivation_path;
//                 key_id = { curve = #secp256k1; name = "dfx_test_key" };
//             });
            
//             let compressed_key_opt = to_compressed_public_key(result.public_key);
//             switch (compressed_key_opt) {
//                 case (null) {
//                     Debug.print("   ❌ Failed to process public key");
//                     ""
//                 };
//                 case (?compressed_key) {
//                     let kaspa_address = Address.address_from_pubkey(compressed_key, Address.ECDSA);
//                     Debug.print("   📍 Path '" # path_text # "' → Address: " # kaspa_address);
//                     kaspa_address
//                 };
//             };
//         } catch (err) {
//             Debug.print("   ❌ Error with derivation path: " # Error.message(err));
//             ""
//         };
//     };

//     // Test signing capability (for future transaction signing)
//     public func test_ecdsa_signing(message: Text) : async ?Blob {
//         Debug.print("🧪 Testing IC ECDSA signing capability...");
        
//         try {
//             // Create a test message hash (in production, this would be a transaction hash)
//             //let message_blob = Text.encodeUtf8(message);
//             let message_blob = Sha256.fromBlob(#sha256, Text.encodeUtf8(message));

//             Cycles.add<system>(30_000_000_000);
            
//             let signature_result = await management_canister.sign_with_ecdsa({
//                 message_hash = message_blob;
//                 derivation_path = [];
//                 key_id = { curve = #secp256k1; name = "dfx_test_key" };
//             });
            
//             Debug.print("   ✅ Signature generated, size: " # Nat.toText(signature_result.signature.size()));
//             Debug.print("   📋 Signature (hex): " # hex_from_array(Blob.toArray(signature_result.signature)));
            
//             ?signature_result.signature
//         } catch (err) {
//             Debug.print("   ❌ Failed to sign: " # Error.message(err));
//             null
//         };
//     };

//     // Test signing capability with BLAKE2b
//     public func test_blake2b_signing(message: Text) : async ?Text {
//         Debug.print("🧪 Testing IC ECDSA signing capability (BLAKE2b)...");
        
//         try {
//             let message_blob = Blake2b.digest(Text.encodeUtf8(message));
//             Debug.print("   📋 Message hash (BLAKE2b): " # hex_from_array(Blob.toArray(message_blob)));

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

//     // Comprehensive test combining all functionality
//     public func run_comprehensive_ic_kaspa_test() : async () {
//         Debug.print("\n🚀 === COMPREHENSIVE IC ECDSA + KASPA TEST ===");
        
//         // Test 1: Basic address generation
//         await test_ecdsa_address_from_ic_public_key();
        
//         // Test 2: Multiple addresses with derivation paths
//         let addr1 = await test_ecdsa_with_derivation_path("kaspa-wallet-1");
//         let addr2 = await test_ecdsa_with_derivation_path("kaspa-wallet-2");
//         let addr3 = await test_ecdsa_with_derivation_path("kaspa-transaction-123");
        
//         Debug.print("\n📍 Generated addresses:");
//         Debug.print("   Wallet 1: " # addr1);
//         Debug.print("   Wallet 2: " # addr2);
//         Debug.print("   Transaction: " # addr3);
        
//         // Test 3: Signing capability
//         let signature_opt = await test_ecdsa_signing("Hello Kaspa from IC!");
//         switch (signature_opt) {
//             case (null) Debug.print("   ⚠️  Signing test failed");
//             case (?_) Debug.print("   ✅ Signing test successful");
//         };
        
//         Debug.print("\n💡 NEXT VERIFICATION STEPS:");
//         Debug.print("1. Copy the public keys and verify with external secp256k1 tools");
//         Debug.print("2. Send small amounts to the generated addresses");
//         Debug.print("3. Test transaction signing and broadcasting");
//         Debug.print("4. Verify signatures are accepted by Kaspa network");
        
//         Debug.print("\n🎉 IC ECDSA + Kaspa integration test completed!");
//     };
// };













import Debug "mo:base/Debug";
   import Blob "mo:base/Blob";
   import Array "mo:base/Array";
   import Text "mo:base/Text";
   import Nat8 "mo:base/Nat8";
   import Nat "mo:base/Nat";
   import Nat32 "mo:base/Nat32";
   import Nat64 "mo:base/Nat64";
   import Cycles "mo:base/ExperimentalCycles";
   import Error "mo:base/Error";
   import Principal "mo:base/Principal";
   import Buffer "mo:base/Buffer";
   import Result "mo:base/Result";
   import Iter "mo:base/Iter";
   import Char "mo:base/Char";
   import Sha256 "mo:sha2/Sha256";

   import Blake2b "mo:blake2b";
   import Address "../kaspa/address";

   persistent actor KaspaTestTecdsa {
       // Data structures
       public type KaspaOutpoint = {
           transactionId : Text;
           index : Nat32;
       };

       public type KaspaInput = {
           previousOutpoint : KaspaOutpoint;
           signatureScript : Text;
           sequence : Nat64;
           sigOpCount : Nat8;
       };

       public type KaspaScriptPublicKey = {
           version : Nat;
           scriptPublicKey : Text;
       };

       public type KaspaOutput = {
           amount : Nat64;
           scriptPublicKey : KaspaScriptPublicKey;
       };

       public type KaspaTransaction = {
           version : Nat;
           inputs : [KaspaInput];
           outputs : [KaspaOutput];
           lockTime : Nat64;
           subnetworkId : Text;
           gas : Nat64;
           payload : Text;
       };

       public type TransactionRequest = {
           transaction : KaspaTransaction;
           allowOrphan : Bool;
       };

       public type UTXO = {
           transactionId : Text;
           index : Nat32;
           amount : Nat64;
           scriptPublicKey : Text;
           scriptVersion : Nat;
           address : Text;
       };

       // Management canister interface
       type ManagementCanister = actor {
           ecdsa_public_key : ({
               canister_id : ?Principal;
               derivation_path : [Blob];
               key_id : { curve : { #secp256k1 }; name : Text };
           }) -> async ({ public_key : Blob });
           sign_with_ecdsa : ({
               message_hash : Blob;
               derivation_path : [Blob];
               key_id : { curve : { #secp256k1 }; name : Text };
           }) -> async ({ signature : Blob });
       };

       let management_canister : ManagementCanister = actor("aaaaa-aa");

       // Helper: Convert compressed public key to scriptPublicKey
       private func to_compressed_public_key(pubkey: Blob) : [Nat8] {
           let bytes = Blob.toArray(pubkey);
           if (bytes.size() == 33) {
               bytes
           } else {
               Debug.print("Invalid public key length: " # Nat.toText(bytes.size()));
               []
           }
       };

       private func hex_from_array(bytes: [Nat8]) : Text {
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

       private func hex_to_bytes(hex: Text) : [Nat8] {
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
                   Debug.print("Invalid hex char: " # Text.fromChar(c));
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

       private func nat32_to_bytes(n: Nat32) : [Nat8] {
           [
               Nat8.fromNat(Nat32.toNat(n & 0xFF)),
               Nat8.fromNat(Nat32.toNat((n >> 8) & 0xFF)),
               Nat8.fromNat(Nat32.toNat((n >> 16) & 0xFF)),
               Nat8.fromNat(Nat32.toNat((n >> 24) & 0xFF))
           ]
       };

       private func text_to_derivation_path(path: Text) : [Blob] {
           let parts = Iter.toArray(Text.split(path, #char '/'));
           let result = Buffer.Buffer<Blob>(parts.size());
           for (part in parts.vals()) {
               if (part != "m") {
                   let is_hardened = Text.endsWith(part, #char '\'');
                   let clean_part = if (is_hardened) {
                       Text.trimEnd(part, #char '\'')
                   } else {
                       part
                   };
                   let bytes = Buffer.Buffer<Nat8>(4);
                   switch (Nat.fromText(clean_part)) {
                       case (null) {
                           Debug.print("Invalid derivation path part: " # part);
                           let num = Nat32.fromNat(0);
                           bytes.append(Buffer.fromArray(nat32_to_bytes(num)));
                           result.add(Blob.fromArray(Buffer.toArray(bytes)));
                       };
                       case (?nat) {
                           let base_num = Nat32.fromNat(nat);
                           let num = if (is_hardened) {
                               base_num + 0x80000000 // Add 2^31 for hardened index
                           } else {
                               base_num
                           };
                           bytes.append(Buffer.fromArray(nat32_to_bytes(num)));
                           result.add(Blob.fromArray(Buffer.toArray(bytes)));
                       };
                   };
               }
           };
           Buffer.toArray(result)
       };

       private func nat_to_le_bytes(n: Nat, len: Nat) : [Nat8] {
           let result = Buffer.Buffer<Nat8>(len);
           var num = n;
           for (_ in Iter.range(0, len - 1)) {
               result.add(Nat8.fromNat(num % 256));
               num /= 256;
           };
           Buffer.toArray(result)
       };

       private func nat64_to_le_bytes(n: Nat64) : [Nat8] {
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

       private func bytes_greater(a: [Nat8], b: [Nat8]) : Bool {
           if (a.size() != 32 or b.size() != 32) return false;
           for (i in Iter.range(0, 31)) {
               if (a[i] > b[i]) return true;
               if (a[i] < b[i]) return false;
           };
           false // Equal
       };

       private func bytes_subtract(n: [Nat8], s: [Nat8]) : [Nat8] {
           if (n.size() != 32 or s.size() != 32) return s;
           var result: [var Nat8] = Array.init<Nat8>(32, 0);
           var borrow: Nat = 0;
           for (i in Iter.range(0, 31)) {
               let j = 31 - i; // Process from least to most significant byte
               let n_val = Nat8.toNat(n[j]);
               let s_val = Nat8.toNat(s[j]);
               let diff = n_val - s_val - borrow;
               if (diff < 0) {
                   result[j] := Nat8.fromNat(diff + 256);
                   borrow := 1;
               } else {
                   result[j] := Nat8.fromNat(diff);
                   borrow := 0;
               };
           };
           Array.freeze(result)
       };

    //    private func der_encode_signature(raw_sig: [Nat8], force_72_bytes: Bool) : [Nat8] {
    //        if (raw_sig.size() != 64) {
    //            Debug.print("   ⚠️ Invalid raw signature size: " # Nat.toText(raw_sig.size()));
    //            return [];
    //        };
    //        let r = Array.subArray<Nat8>(raw_sig, 0, 32);
    //        let s = Array.subArray<Nat8>(raw_sig, 32, 32);
           
    //        // secp256k1 half-order (n/2) as 32-byte array (big-endian)
    //        let half_order : [Nat8] = [
    //            0x7F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    //            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    //            0x5D, 0x57, 0x6E, 0x73, 0x57, 0xA4, 0x50, 0x1D,
    //            0xDF, 0xE9, 0x2F, 0x46, 0x68, 0x1B, 0x20, 0xA0
    //        ];
    //        // Curve order (n) for subtraction
    //        let curve_order : [Nat8] = [
    //            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    //            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE,
    //            0xBA, 0xAE, 0xDC, 0xE6, 0xAF, 0x48, 0xA0, 0x3B,
    //            0xBF, 0xD2, 0x5E, 0x8C, 0xD0, 0x36, 0x41, 0x41
    //        ];

    //        // Normalize s to low-S
    //        let s_bytes = if (bytes_greater(s, half_order)) {
    //            let s_neg = bytes_subtract(curve_order, s);
    //            Debug.print("   🔍 Normalizing high-S to low-S: " # hex_from_array(s) # " -> " # hex_from_array(s_neg));
    //            s_neg
    //        } else {
    //            s
    //        };

    //        // Only pad if the most significant byte is > 0x7F (DER encoding rule)
    //        let r_bytes = if (r[0] > 0x7F) {
    //            Array.append<Nat8>([0x00], r) // Pad to 33 bytes
    //        } else {
    //            r
    //        };
    //        let s_bytes_padded = if (s_bytes[0] > 0x7F) {
    //            Array.append<Nat8>([0x00], s_bytes) // Pad to 33 bytes
    //        } else {
    //            s_bytes
    //        };
           
    //        let r_len = r_bytes.size();
    //        let s_len = s_bytes_padded.size();
    //        let content_len = r_len + s_len + 4; // 2 for r/s tags, 2 for lengths
    //        let header : [Nat8] = [0x30, Nat8.fromNat(content_len)];
    //        let r_header : [Nat8] = [0x02, Nat8.fromNat(r_len)];
    //        let s_header : [Nat8] = [0x02, Nat8.fromNat(s_len)];
    //        let result = Array.append<Nat8>(
    //            Array.append<Nat8>(
    //                Array.append<Nat8>(header, r_header),
    //                r_bytes
    //            ),
    //            Array.append<Nat8>(s_header, s_bytes_padded)
    //        );
    //        Debug.print("   🔍 DER-encoded signature: " # hex_from_array(result) # ", length: " # Nat.toText(result.size()));
    //        Debug.print("   🔍 r: " # hex_from_array(r_bytes) # ", length: " # Nat.toText(r_len));
    //        Debug.print("   🔍 s: " # hex_from_array(s_bytes_padded) # ", length: " # Nat.toText(s_len));
    //        result
    //    };

    // Encode raw ECDSA signature to DER format
private func der_encode_signature(raw_sig: [Nat8], force_72_bytes: Bool) : [Nat8] {
  Debug.print(" 🔍 Encoding DER signature, raw length: " # Nat.toText(raw_sig.size()));
  if (raw_sig.size() != 64) {
    Debug.print(" ❌ Invalid raw signature length: " # Nat.toText(raw_sig.size()));
    return [];
  };

  let r = Array.subArray(raw_sig, 0, 32);
  let s = Array.subArray(raw_sig, 32, 32);

  // Only add leading zero if necessary (high bit set)
  let r_clean = if (r[0] >= 0x80) {
    Debug.print(" 🔍 Adding leading zero to r");
    Array.append([0x00:Nat8], r)
  } else {
    // Remove leading zeros for minimal encoding
    var start = 0;
    while (start < r.size() - 1 and r[start] == 0) {
      start += 1;
    };
    Array.subArray(r, start, r.size() - start)
  };
  let s_clean = if (s[0] >= 0x80) {
    Debug.print(" 🔍 Adding leading zero to s");
    Array.append([0x00:Nat8], s)
  } else {
    var start = 0;
    while (start < s.size() - 1 and s[start] == 0) {
      start += 1;
    };
    Array.subArray(s, start, s.size() - start)
  };

  // Ensure low-S (secp256k1 order: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141)
  let n = hex_to_bytes("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141");
  var s_final = s_clean;
  let half_n = Array.subArray(n, 16, 16); // Approximate n/2
  if (compare_bytes(s_clean, half_n) > 0) {
    s_final := subtract_bytes(n, s_clean);
    Debug.print(" 🔍 Using low-S value");
  };

  let r_len = Nat8.fromNat(r_clean.size());
  let s_len = Nat8.fromNat(s_final.size());
  let total_len = Nat8.fromNat(4 + r_clean.size() + s_final.size());

  let der = Buffer.Buffer<Nat8>(6 + r_clean.size() + s_final.size());
  der.add(0x30); // Sequence tag
  der.add(total_len);
  der.add(0x02); // Integer tag for r
  der.add(r_len);
  der.append(Buffer.fromArray(r_clean));
  der.add(0x02); // Integer tag for s
  der.add(s_len);
  der.append(Buffer.fromArray(s_final));

  let result = Buffer.toArray(der);
  if (result.size() > 71 and not force_72_bytes) {
    Debug.print(" ⚠️ DER signature too long: " # Nat.toText(result.size()) # " bytes");
  };
  Debug.print(" ✅ DER signature: " # hex_from_array(result));
  result
};

// Helper to compare bytes (for high-S check)
private func compare_bytes(a: [Nat8], b: [Nat8]) : Int {
  let len = Nat.min(a.size(), b.size());
  for (i in Iter.range(0, len - 1)) {
    if (a[i] < b[i]) return -1;
    if (a[i] > b[i]) return 1;
  };
  if (a.size() < b.size()) return -1;
  if (a.size() > b.size()) return 1;
  0
};

// Helper to subtract bytes (for low-S)
private func subtract_bytes(a: [Nat8], b: [Nat8]) : [Nat8] {
  let result = Buffer.Buffer<Nat8>(a.size());
  var borrow = 0;
  for (i in Iter.range(0, a.size() - 1)) {
    let ai = Nat8.toNat(a[a.size() - 1 - i]);
    let bi = if (i < b.size()) { Nat8.toNat(b[b.size() - 1 - i]) } else { 0 };
    let diff = ai - bi - borrow;
    if (diff < 0) {
      result.add(Nat8.fromNat(diff + 256));
      borrow := 1;
    } else {
      result.add(Nat8.fromNat(diff));
      borrow := 0;
    };
  };
  let reversed = Buffer.toArray(result);
  Array.reverse(reversed)
};

    //    private func sign_transaction_input(
    //         tx: KaspaTransaction,
    //         input_index: Nat,
    //         utxo: UTXO,
    //         derivation_path: Text,
    //         force_72_bytes: Bool
    //     ) : async ?Text {
    //         Debug.print("🖌️ Signing input " # Nat.toText(input_index) # "...");
    //         let sighash = calculate_sighash(tx, input_index, utxo);
    //         Debug.print("   🔢 Sighash for input " # Nat.toText(input_index) # ": " # hex_from_array(sighash));
    //         Debug.print("   🔍 Sighash length: " # Nat.toText(sighash.size()));
            
    //         try {
    //             Cycles.add<system>(30_000_000_000);
    //             let signature_result = await management_canister.sign_with_ecdsa({
    //                 message_hash = Blob.fromArray(sighash);
    //                 derivation_path = []; // Use empty derivation path
    //                 key_id = { curve = #secp256k1; name = "test_key_1" };
    //             });
                
    //             let raw_sig = Blob.toArray(signature_result.signature);
    //             if (raw_sig.size() != 64) {
    //                 Debug.print("   ❌ Invalid raw signature size: " # Nat.toText(raw_sig.size()));
    //                 return null;
    //             };
                
    //             // Use raw signature directly with SIGHASH_ALL
    //             let sig_bytes = Array.append<Nat8>(raw_sig, [0x01]); // 64 bytes + SIGHASH_ALL
    //             Debug.print("   ✅ Raw signature: " # hex_from_array(raw_sig) # ", length: " # Nat.toText(raw_sig.size()));
    //             Debug.print("   ✅ Signature with SIGHASH_ALL: " # hex_from_array(sig_bytes) # ", length: " # Nat.toText(sig_bytes.size()));
                
    //             let sig_len = Nat8.fromNat(sig_bytes.size());
    //             let script_hex = hex_from_array([sig_len]) # hex_from_array(sig_bytes);
    //             Debug.print("   ✅ SignatureScript: " # script_hex # ", total length: " # Nat.toText(sig_bytes.size() + 1));
    //             ?script_hex
    //         } catch (err) {
    //             Debug.print("   ❌ Failed to sign input: " # Error.message(err));
    //             null
    //         }
    //     };
    private func sign_transaction_input(
        tx: KaspaTransaction,
        input_index: Nat,
        utxo: UTXO,
        derivation_path: Text,
        force_72_bytes: Bool
    ) : async ?Text {   
        Debug.print("🖌️ Signing input " # Nat.toText(input_index) # "...");
        let sighash = calculate_sighash(tx, input_index, utxo);
        Debug.print("   🔢 Sighash for input " # Nat.toText(input_index) # ": " # hex_from_array(sighash));
        
        try {
            Cycles.add<system>(30_000_000_000);
            let signature_result = await management_canister.sign_with_ecdsa({
                message_hash = Blob.fromArray(sighash);
                derivation_path = []; // Use empty derivation path
                key_id = { curve = #secp256k1; name = "dfx_test_key" };
            });
            
            let raw_sig = Blob.toArray(signature_result.signature);
            if (raw_sig.size() != 64) {
                Debug.print("   ❌ Invalid raw signature size: " # Nat.toText(raw_sig.size()));
                return null;
            };
            
            // Get the public key for this derivation path
            Cycles.add<system>(30_000_000_000);
            let pubkey_result = await management_canister.ecdsa_public_key({
                canister_id = null;
                derivation_path = []; // Use same derivation path as signing
                key_id = { curve = #secp256k1; name = "dfx_test_key" };
            });
            
            let compressed_pubkey = to_compressed_public_key(pubkey_result.public_key);
            
            // Create proper signature script: <signature> <pubkey>
            let sig_with_sighash = Array.append<Nat8>(raw_sig, [0x01]); // 64 bytes + SIGHASH_ALL
            let sig_len = Nat8.fromNat(sig_with_sighash.size());
            let pubkey_len = Nat8.fromNat(compressed_pubkey.size());
            
            // Build the script: [sig_len][signature][pubkey_len][pubkey]
            let script_bytes = Buffer.Buffer<Nat8>(0);
            script_bytes.add(sig_len);
            script_bytes.append(Buffer.fromArray(sig_with_sighash));
            script_bytes.add(pubkey_len);
            script_bytes.append(Buffer.fromArray(compressed_pubkey));
            
            let script_hex = hex_from_array(Buffer.toArray(script_bytes));
            Debug.print("   ✅ Complete SignatureScript: " # script_hex);
            Debug.print("   🔍 Signature part: " # hex_from_array([sig_len]) # hex_from_array(sig_with_sighash));
            Debug.print("   🔍 PubKey part: " # hex_from_array([pubkey_len]) # hex_from_array(compressed_pubkey));
            
            ?script_hex
        } catch (err) {
            Debug.print("   ❌ Failed to sign input: " # Error.message(err));
            null
        }
    };

       
       private func calculate_sighash(tx: KaspaTransaction, input_index: Nat, utxo: UTXO) : [Nat8] {
           Debug.print("🔢 Calculating sighash for input " # Nat.toText(input_index) # "...");
           let preimage = Buffer.Buffer<Nat8>(0);

           let version_bytes = nat_to_le_bytes(tx.version, 2);
           preimage.append(Buffer.fromArray(version_bytes));
           Debug.print("   🔍 Sighash: Version bytes: " # hex_from_array(version_bytes));

           let prevouts = Buffer.Buffer<Nat8>(0);
           for (input in tx.inputs.vals()) {
               prevouts.append(Buffer.fromArray(hex_to_bytes(input.previousOutpoint.transactionId)));
               prevouts.append(Buffer.fromArray(nat32_to_bytes(input.previousOutpoint.index)));
           };
           let prevouts_bytes = Buffer.toArray(prevouts);
           Debug.print("   🔍 Sighash: Prevouts bytes: " # hex_from_array(prevouts_bytes));
           let prevouts_hash = Blake2b.hash(Blob.fromArray(prevouts_bytes), ?{ digest_length = 32; key = null; salt = null; personal = null });
           preimage.append(Buffer.fromArray(Blob.toArray(prevouts_hash)));
           Debug.print("   🔍 Sighash: PreviousOutputsHash: " # hex_from_array(Blob.toArray(prevouts_hash)));

           let sequences = Buffer.Buffer<Nat8>(0);
           for (input in tx.inputs.vals()) {
               sequences.append(Buffer.fromArray(nat64_to_le_bytes(input.sequence)));
           };
           let sequences_bytes = Buffer.toArray(sequences);
           Debug.print("   🔍 Sighash: Sequences bytes: " # hex_from_array(sequences_bytes));
           let sequences_hash = Blake2b.hash(Blob.fromArray(sequences_bytes), ?{ digest_length = 32; key = null; salt = null; personal = null });
           preimage.append(Buffer.fromArray(Blob.toArray(sequences_hash)));
           Debug.print("   🔍 Sighash: SequencesHash: " # hex_from_array(Blob.toArray(sequences_hash)));

           let sigopcounts = Buffer.Buffer<Nat8>(0);
           for (input in tx.inputs.vals()) {
               sigopcounts.add(input.sigOpCount);
           };
           let sigopcounts_bytes = Buffer.toArray(sigopcounts);
           Debug.print("   🔍 Sighash: SigOpCounts bytes: " # hex_from_array(sigopcounts_bytes));
           let sigopcounts_hash = Blake2b.hash(Blob.fromArray(sigopcounts_bytes), ?{ digest_length = 32; key = null; salt = null; personal = null });
           preimage.append(Buffer.fromArray(Blob.toArray(sigopcounts_hash)));
           Debug.print("   🔍 Sighash: SigOpCountsHash: " # hex_from_array(Blob.toArray(sigopcounts_hash)));

           let input = tx.inputs[input_index];
           preimage.append(Buffer.fromArray(hex_to_bytes(input.previousOutpoint.transactionId)));
           Debug.print("   🔍 Sighash: TxID: " # input.previousOutpoint.transactionId);
           preimage.append(Buffer.fromArray(nat32_to_bytes(input.previousOutpoint.index)));
           Debug.print("   🔍 Sighash: Index bytes: " # hex_from_array(nat32_to_bytes(input.previousOutpoint.index)));
           
           let script_version_bytes = nat_to_le_bytes(utxo.scriptVersion, 2);
           preimage.append(Buffer.fromArray(script_version_bytes));
           Debug.print("   🔍 Sighash: Script version bytes: " # hex_from_array(script_version_bytes));

           let script_bytes = hex_to_bytes(utxo.scriptPublicKey);
           let script_len = Nat8.fromNat(script_bytes.size());
           preimage.add(script_len);
           preimage.append(Buffer.fromArray(script_bytes));
           Debug.print("   🔍 Sighash: ScriptPubKey length: " # Nat.toText(script_bytes.size()));
           Debug.print("   🔍 Sighash: ScriptPubKey bytes: " # hex_from_array(script_bytes));

           let amount_bytes = nat64_to_le_bytes(utxo.amount);
           preimage.append(Buffer.fromArray(amount_bytes));
           Debug.print("   🔍 Sighash: Amount bytes: " # hex_from_array(amount_bytes));

           preimage.append(Buffer.fromArray(nat64_to_le_bytes(input.sequence)));
           Debug.print("   🔍 Sighash: Sequence bytes: " # hex_from_array(nat64_to_le_bytes(input.sequence)));

           preimage.add(input.sigOpCount);
           Debug.print("   🔍 Sighash: SigOpCount byte: " # hex_from_array([input.sigOpCount]));

           let outputs = Buffer.Buffer<Nat8>(0);
           for (output in tx.outputs.vals()) {
               outputs.append(Buffer.fromArray(nat64_to_le_bytes(output.amount)));
               outputs.append(Buffer.fromArray(nat_to_le_bytes(output.scriptPublicKey.version, 2)));
               let script_bytes = hex_to_bytes(output.scriptPublicKey.scriptPublicKey);
               outputs.add(Nat8.fromNat(script_bytes.size()));
               outputs.append(Buffer.fromArray(script_bytes));
           };
           let outputs_bytes = Buffer.toArray(outputs);
           Debug.print("   🔍 Sighash: Outputs bytes: " # hex_from_array(outputs_bytes));
           let outputs_hash = Blake2b.hash(Blob.fromArray(outputs_bytes), ?{ digest_length = 32; key = null; salt = null; personal = null });
           preimage.append(Buffer.fromArray(Blob.toArray(outputs_hash)));
           Debug.print("   🔍 Sighash: OutputsHash: " # hex_from_array(Blob.toArray(outputs_hash)));

           let locktime_bytes = nat64_to_le_bytes(tx.lockTime);
           preimage.append(Buffer.fromArray(locktime_bytes));
           Debug.print("   🔍 Sighash: Locktime bytes: " # hex_from_array(locktime_bytes));

           let subnetwork_bytes = hex_to_bytes(tx.subnetworkId);
           preimage.append(Buffer.fromArray(subnetwork_bytes));
           Debug.print("   🔍 Sighash: SubnetworkID bytes: " # hex_from_array(subnetwork_bytes));

           let gas_bytes = nat64_to_le_bytes(tx.gas);
           preimage.append(Buffer.fromArray(gas_bytes));
           Debug.print("   🔍 Sighash: Gas bytes: " # hex_from_array(gas_bytes));

           let payload_bytes = hex_to_bytes(tx.payload);
           let payload_hash = Blake2b.hash(Blob.fromArray(payload_bytes), ?{ digest_length = 32; key = null; salt = null; personal = null });
           preimage.append(Buffer.fromArray(Blob.toArray(payload_hash)));
           Debug.print("   🔍 Sighash: PayloadHash: " # hex_from_array(Blob.toArray(payload_hash)));

           let sighash_type = [0x01 : Nat8]; // SIGHASH_ALL
           preimage.append(Buffer.fromArray(sighash_type));
           Debug.print("   🔍 Sighash: Sighash type: " # hex_from_array(sighash_type));

           let final_preimage = Buffer.toArray(preimage);
           Debug.print("   🔍 Sighash: Final preimage: " # hex_from_array(final_preimage));
           let final_hash = Blake2b.hash(Blob.fromArray(final_preimage), ?{ digest_length = 32; key = null; salt = null; personal = null });
           Debug.print("   🔍 Sighash: Final hash: " # hex_from_array(Blob.toArray(final_hash)));
           Debug.print("   🔍 Sighash length: " # Nat.toText(Blob.toArray(final_hash).size()));
           Blob.toArray(final_hash)
       };

       private func validate_transaction(tx: KaspaTransaction, utxos: [UTXO]) : Bool {
           Debug.print("🔍 Validating transaction...");
           var total_in : Nat64 = 0;
           var total_out : Nat64 = 0;

           if (tx.inputs.size() == 0) {
               Debug.print("   ❌ No inputs");
               return false;
           };

           if (tx.outputs.size() == 0) {
               Debug.print("   ❌ No outputs");
               return false;
           };

           for (i in Iter.range(0, tx.inputs.size() - 1)) {
               if (i >= utxos.size()) {
                   Debug.print("   ❌ Missing UTXO for input " # Nat.toText(i));
                   return false;
               };
               total_in += utxos[i].amount;
           };

           for (output in tx.outputs.vals()) {
               total_out += output.amount;
           };

           if (total_in < total_out) {
               Debug.print("   ❌ Insufficient input amount: " # Nat64.toText(total_in) # " < " # Nat64.toText(total_out));
               return false;
           };

           Debug.print("   ✅ Transaction validated successfully");
           true
       };

       public func generate_address_with_script(derivation_path: Text) : async ?(Text, Text) {
           Debug.print("🔑 Generating address for derivation path: " # derivation_path # " -> ");
           try {
               Cycles.add<system>(30_000_000_000);
               let pubkey_result = await management_canister.ecdsa_public_key({
                   canister_id = null;
                //    derivation_path = text_to_derivation_path(derivation_path);
                derivation_path = [];
                   key_id = { curve = #secp256k1; name = "dfx_test_key" };
               });
               let raw_pubkey = Blob.toArray(pubkey_result.public_key);
               Debug.print("   ✅ Raw public key: " # hex_from_array(raw_pubkey));
               
               let compressed_pubkey = to_compressed_public_key(pubkey_result.public_key);
               Debug.print("   ✅ Compressed public key: " # hex_from_array(compressed_pubkey));
               
               let script_bytes = Array.append<Nat8>(
                   [Nat8.fromNat(compressed_pubkey.size())],
                   Array.append<Nat8>(compressed_pubkey, [0xAC])
               );
               let script_hex = hex_from_array(script_bytes);
               Debug.print("   ✅ Generated scriptPublicKey: " # script_hex);
               
               let address = Address.address_from_pubkey(Blob.fromArray(compressed_pubkey), Address.ECDSA);
               Debug.print("   ✅ Generated address: " # address);
               ?(address, script_hex)
           } catch (err) {
               Debug.print("   ❌ Failed to generate public key: " # Error.message(err));
               null
           }
       };

       private func transaction_request_to_json(request: TransactionRequest) : Text {
           let tx = request.transaction;
           let inputs_json = Buffer.Buffer<Text>(tx.inputs.size());
           for (input in tx.inputs.vals()) {
               inputs_json.add(
                   "{\"previousOutpoint\":{\"transactionId\":\"" # input.previousOutpoint.transactionId #
                   "\",\"index\":" # Nat32.toText(input.previousOutpoint.index) #
                   "},\"signatureScript\":\"" # input.signatureScript #
                   "\",\"sequence\":" # Nat64.toText(input.sequence) #
                   ",\"sigOpCount\":" # Nat8.toText(input.sigOpCount) # "}"
               );
           };
           let outputs_json = Buffer.Buffer<Text>(tx.outputs.size());
           for (output in tx.outputs.vals()) {
               outputs_json.add(
                   "{\"amount\":" # Nat64.toText(output.amount) #
                   ",\"scriptPublicKey\":{\"version\":" # Nat.toText(output.scriptPublicKey.version) #
                   ",\"scriptPublicKey\":\"" # output.scriptPublicKey.scriptPublicKey # "\"}}"
               );
           };
           "{\"transaction\":{\"version\":" # Nat.toText(tx.version) #
           ",\"inputs\":[" # Text.join(",", inputs_json.vals()) #
           "],\"outputs\":[" # Text.join(",", outputs_json.vals()) #
           "],\"lockTime\":" # Nat64.toText(tx.lockTime) #
           ",\"subnetworkId\":\"" # tx.subnetworkId #
           "\",\"gas\":" # Nat64.toText(tx.gas) #
           ",\"payload\":\"" # tx.payload #
           "\"},\"allowOrphan\":" # (if (request.allowOrphan) "true" else "false") # "}"
       };

    //    public func build_transaction(
    //        sender: Text,
    //        recipient: Text,
    //        amount: Nat64,
    //        fee: Nat64,
    //        use_ac: Bool,
    //        force_72_bytes: Bool
    //    ) : async ?TransactionRequest {
    //        Debug.print("🏗️ Building Kaspa transaction...");
    //        Debug.print("   📫 Sender: " # sender);
    //        Debug.print("   📫 Recipient: " # recipient);
    //        Debug.print("   💰 Amount: " # Nat64.toText(amount) # " sompi");
    //        Debug.print("   💸 Fee: " # Nat64.toText(fee) # " sompi");
    //        Debug.print("   🔧 Using opcode: " # (if (use_ac) "0xAC" else "0xAB"));
    //        Debug.print("   🔧 Force 72-byte DER: " # (if (force_72_bytes) "true" else "false"));

    //        let utxos : [UTXO] = [{
    //            transactionId = "1e082841b49cd9aaf847388371a227561bd715dc79805a519f059b65a668f124";
    //            index = 0;
    //            amount = 100000000; // 1 KAS
    //            scriptPublicKey = "2102219f48df455684794a1a20f8bfc3904365ce55a42d8a1c44541480ba4ed71f61" # (if (use_ac) "ac" else "ab");
    //            scriptVersion = 0;
    //            address = "kaspa:qypzr86gmaz4dprefgdzp79lcwgyxeww2kjzmzsug32pfq96fmt37cg65e4up0j";
    //        }];

    //        Debug.print("   📊 UTXOs: " # Nat.toText(utxos.size()));
    //        Debug.print("   💰 Amount: " # Nat64.toText(amount) # " sompi");
    //        Debug.print("   💸 Fee: " # Nat64.toText(fee) # " sompi");

    //        let total_in : Nat64 = utxos[0].amount;
    //        if (total_in < amount + fee) {
    //            Debug.print("   ❌ Insufficient funds: " # Nat64.toText(total_in) # " < " # Nat64.toText(amount + fee));
    //            return null;
    //        };

    //        let change = total_in - amount - fee;
    //        Debug.print("   🔄 Change: " # Nat64.toText(change) # " sompi");

    //        let recipient_script = hex_to_bytes("200099e53094a3fbe8df4fd0db8f92d85f50c3802ede184706de990c46fcdcc503ac");
    //        let change_script = hex_to_bytes("205b7fb28a9e0ef867bcfc85a6400a89bf35ceaada43aa8f7d8e59a1c4f171b8a1ac");
    //        Debug.print("   📫 Using change scriptPublicKey: " # hex_from_array(change_script));

    //        let tx : KaspaTransaction = {
    //            version = 0;
    //            inputs = [{
    //                previousOutpoint = {
    //                    transactionId = utxos[0].transactionId;
    //                    index = utxos[0].index;
    //                };
    //                signatureScript = "";
    //                sequence = 0xFFFFFFFFFFFFFFFF;
    //                sigOpCount = 1;
    //            }];
    //            outputs = [
    //                {
    //                    amount = amount;
    //                    scriptPublicKey = {
    //                        version = 0;
    //                        scriptPublicKey = hex_from_array(recipient_script);
    //                    };
    //                },
    //                {
    //                    amount = change;
    //                    scriptPublicKey = {
    //                        version = 0;
    //                        scriptPublicKey = hex_from_array(change_script);
    //                    };
    //                }
    //            ];
    //            lockTime = 0;
    //            subnetworkId = "0000000000000000000000000000000000000000";
    //            gas = 0;
    //            payload = "";
    //        };

    //        if (not validate_transaction(tx, utxos)) {
    //            Debug.print("   ❌ Transaction validation failed");
    //            return null;
    //        };

    //        switch (await sign_transaction_input(tx, 0, utxos[0], "m/44'/0'/0'/0/0", force_72_bytes)) {
    //            case (null) {
    //                Debug.print("   ❌ Failed to sign input 0");
    //                null
    //            };
    //            case (?signature_script) {
    //                Debug.print("   ✅ Signed input 0");
    //                let signed_tx : KaspaTransaction = {
    //                    version = tx.version;
    //                    inputs = [{
    //                        previousOutpoint = {
    //                            transactionId = utxos[0].transactionId;
    //                            index = utxos[0].index;
    //                        };
    //                        signatureScript = signature_script;
    //                        sequence = tx.inputs[0].sequence;
    //                        sigOpCount = tx.inputs[0].sigOpCount;
    //                    }];
    //                    outputs = tx.outputs;
    //                    lockTime = tx.lockTime;
    //                    subnetworkId = tx.subnetworkId;
    //                    gas = tx.gas;
    //                    payload = tx.payload;
    //                };

    //                if (not validate_transaction(signed_tx, utxos)) {
    //                    Debug.print("   ❌ Signed transaction validation failed");
    //                    return null;
    //                };

    //                Debug.print("   🎉 Transaction built and signed successfully!");
    //                ?{
    //                    transaction = signed_tx;
    //                    allowOrphan = false;
    //                }
    //            }
    //        }
    //    };

    public func build_transaction(
    sender: Text,
    recipient: Text,
    amount: Nat64,
    fee: Nat64,
    use_ac: Bool,
    force_72_bytes: Bool
) : async ?TransactionRequest {
    Debug.print("🏗️ Building Kaspa transaction...");
    Debug.print("   📫 Sender: " # sender);
    Debug.print("   📫 Recipient: " # recipient);
    Debug.print("   💰 Amount: " # Nat64.toText(amount) # " sompi");
    Debug.print("   💸 Fee: " # Nat64.toText(fee) # " sompi");
    Debug.print("   🔧 Using opcode: " # (if (use_ac) "0xAC" else "0xAB"));

    // First get the actual public key to ensure consistency
    let pubkey_result = try {
        Cycles.add<system>(30_000_000_000);
        await management_canister.ecdsa_public_key({
            canister_id = null;
            derivation_path = []; // Use empty derivation path
            key_id = { curve = #secp256k1; name = "dfx_test_key" };
        });
    } catch (err) {
        Debug.print("   ❌ Failed to get public key: " # Error.message(err));
        return null;
    };
    
    let compressed_pubkey = to_compressed_public_key(pubkey_result.public_key);
    let actual_script_pubkey = Array.append<Nat8>(
        [Nat8.fromNat(compressed_pubkey.size())],
        Array.append<Nat8>(compressed_pubkey, [if (use_ac) 0xAC else 0xAB])
    );
    
    Debug.print("   🔑 Using actual pubkey: " # hex_from_array(compressed_pubkey));
    Debug.print("   📜 Actual scriptPubKey: " # hex_from_array(actual_script_pubkey));

    // Your actual UTXO from the API
    let utxos : [UTXO] = [{
        transactionId = "75b23c8a72ed66a1a9b0111a609b20314a9fe873785ab931cec1b3846e0eeafd";
        index = 1;
        amount = 400000000; // 4 KAS
        scriptPublicKey = "210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab";
        scriptVersion = 0;
        address = "kaspa:qypff6urmgk8452vjx55r63dhc38s6ewlavknmnefzgac42n3lt8cdchp86su6n";
    }];

    // let utxos : [UTXO] = [{
    //     transactionId = "1e082841b49cd9aaf847388371a227561bd715dc79805a519f059b65a668f124";
    //     index = 0;
    //     amount = 100000000; // 1 KAS
    //     scriptPublicKey = hex_from_array(actual_script_pubkey); // Use the actual scriptPubKey
    //     scriptVersion = 0;
    //     // address = "kaspa:qypzr86gmaz4dprefgdzp79lcwgyxeww2kjzmzsug32pfq96fmt37cg65e4up0j";
    //     address = "kaspa:qypff6urmgk8452vjx55r63dhc38s6ewlavknmnefzgac42n3lt8cdchp86su6n";
    // }];

    // Rest of the function remains the same...
    let total_in : Nat64 = utxos[0].amount;
    if (total_in < amount + fee) {
        Debug.print("   ❌ Insufficient funds: " # Nat64.toText(total_in) # " < " # Nat64.toText(amount + fee));
        return null;
    };

    let change = total_in - amount - fee;
    Debug.print("   🔄 Change: " # Nat64.toText(change) # " sompi");

    let recipient_script = hex_to_bytes("200099e53094a3fbe8df4fd0db8f92d85f50c3802ede184706de990c46fcdcc503ac");
    // let change_script = hex_to_bytes("205b7fb28a9e0ef867bcfc85a6400a89bf35ceaada43aa8f7d8e59a1c4f171b8a1ac");
    let change_script = hex_to_bytes("210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab");

    let tx : KaspaTransaction = {
        version = 0;
        inputs = [{
            previousOutpoint = {
                transactionId = utxos[0].transactionId;
                index = utxos[0].index;
            };
            signatureScript = "";
            sequence = 0xFFFFFFFFFFFFFFFF;
            sigOpCount = 1;
        }];
        outputs = [
            {
                amount = amount;
                scriptPublicKey = {
                    version = 0;
                    scriptPublicKey = hex_from_array(recipient_script);
                };
            },
            {
                amount = change;
                scriptPublicKey = {
                    version = 0;
                    scriptPublicKey = hex_from_array(change_script);
                };
            }
        ];
        lockTime = 0;
        subnetworkId = "0000000000000000000000000000000000000000";
        gas = 0;
        payload = "";
    };

    if (not validate_transaction(tx, utxos)) {
        Debug.print("   ❌ Transaction validation failed");
        return null;
    };

    switch (await sign_transaction_input(tx, 0, utxos[0], "m/44'/0'/0'/0/0", force_72_bytes)) {
        case (null) {
            Debug.print("   ❌ Failed to sign input 0");
            null
        };
        case (?signature_script) {
            Debug.print("   ✅ Signed input 0");
            let signed_tx : KaspaTransaction = {
                version = tx.version;
                inputs = [{
                    previousOutpoint = {
                        transactionId = utxos[0].transactionId;
                        index = utxos[0].index;
                    };
                    signatureScript = signature_script;
                    sequence = tx.inputs[0].sequence;
                    sigOpCount = tx.inputs[0].sigOpCount;
                }];
                outputs = tx.outputs;
                lockTime = tx.lockTime;
                subnetworkId = tx.subnetworkId;
                gas = tx.gas;
                payload = tx.payload;
            };

            if (not validate_transaction(signed_tx, utxos)) {
                Debug.print("   ❌ Signed transaction validation failed");
                return null;
            };

            Debug.print("   🎉 Transaction built and signed successfully!");
            ?{
                transaction = signed_tx;
                allowOrphan = false;
            }
        }
    }
};

       public func test_ecdsa_signing(message: Text, force_72_bytes: Bool) : async ?Text {
           Debug.print("🧪 Testing IC ECDSA signing capability (BLAKE2b-256)...");
           
           try {
               let message_blob = Blake2b.hash(Text.encodeUtf8(message), ?{
                   digest_length = 32;
                   key = null;
                   salt = null;
                   personal = null;
               });
               Debug.print("   📋 Message hash (BLAKE2b-256): " # hex_from_array(Blob.toArray(message_blob)));
               Debug.print("   🔍 Message hash length: " # Nat.toText(Blob.toArray(message_blob).size()));

               Cycles.add<system>(30_000_000_000);
               
               let signature_result = await management_canister.sign_with_ecdsa({
                   message_hash = message_blob;
                   derivation_path = text_to_derivation_path("m/44'/0'/0'/0/0");
                   key_id = { curve = #secp256k1; name = "dfx_test_key" };
               });
               
               let raw_sig = Blob.toArray(signature_result.signature);
               let der_sig = der_encode_signature(raw_sig, force_72_bytes);
               let sig_bytes = Array.append<Nat8>(der_sig, [0x01]); // SIGHASH_ALL
               Debug.print("   ✅ Raw signature: " # hex_from_array(raw_sig) # ", length: " # Nat.toText(raw_sig.size()));
               Debug.print("   ✅ DER-encoded signature: " # hex_from_array(der_sig) # ", length: " # Nat.toText(der_sig.size()));
               Debug.print("   ✅ Signature with SIGHASH_ALL: " # hex_from_array(sig_bytes) # ", length: " # Nat.toText(sig_bytes.size()));
               
               let sig_len = Nat8.fromNat(sig_bytes.size());
               let script_hex = hex_from_array([sig_len]) # hex_from_array(sig_bytes);
               Debug.print("   ✅ SignatureScript: " # script_hex # ", total length: " # Nat.toText(sig_bytes.size() + 1));
               ?script_hex
           } catch (err) {
               Debug.print("   ❌ Failed to sign: " # Error.message(err));
               null
           }
       };

       public func test_transaction_building(use_ac: Bool, force_72_bytes: Bool) : async ?Text {
           Debug.print("🧪 TESTING TRANSACTION BUILDING ===");
           let sender = "kaspa:qypff6urmgk8452vjx55r63dhc38s6ewlavknmnefzgac42n3lt8cdchp86su6n"; //"kaspa:qypzr86gmaz4dprefgdzp79lcwgyxeww2kjzmzsug32pfq96fmt37cg65e4up0j";
           let recipient = "kaspa:qpdhlv52nc80seauljz6vsq23xlntn42mfp64rma3ev6r383wxu2z8kakh68k";//"kaspa:qqqfnefsjj3lh6xlflgdhrujmp04psuq9m0ps3cxm6vsc3humnzsxrdcg8dc4";
           let amount : Nat64 = 10000000; // 0.1 KAS
           let fee : Nat64 = 10000; // 0.0001 KAS
           
           switch (await build_transaction(sender, recipient, amount, fee, use_ac, force_72_bytes)) {
               case (null) {
                   Debug.print("   ❌ Transaction building failed");
                   null
               };
               case (?request) {
                   Debug.print("   ✅ Transaction created successfully!");
                   Debug.print("   📋 Inputs: " # Nat.toText(request.transaction.inputs.size()));
                   Debug.print("   📋 Outputs: " # Nat.toText(request.transaction.outputs.size()));
                   var total_out : Nat64 = 0;
                   for (output in request.transaction.outputs.vals()) {
                       total_out += output.amount;
                   };
                   Debug.print("   📋 Total outputs value: " # Nat64.toText(total_out) # " sompi");
                   let json = transaction_request_to_json(request);
                   Debug.print("   📤 JSON for submission: " # json);
                   ?json
               }
           }
       };

       public func debug_sighash(use_ac: Bool) : async ?Text {
           Debug.print("🧪 Debugging sighash...");
           let utxos : [UTXO] = [{
               transactionId = "1e082841b49cd9aaf847388371a227561bd715dc79805a519f059b65a668f124";
               index = 0;
               amount = 100000000; // 1 KAS
               scriptPublicKey = "2102219f48df455684794a1a20f8bfc3904365ce55a42d8a1c44541480ba4ed71f61" # (if (use_ac) "ac" else "ab");
               scriptVersion = 0;
               address = "kaspa:qypff6urmgk8452vjx55r63dhc38s6ewlavknmnefzgac42n3lt8cdchp86su6n"; //"kaspa:qypzr86gmaz4dprefgdzp79lcwgyxeww2kjzmzsug32pfq96fmt37cg65e4up0j";
           }];

           let tx : KaspaTransaction = {
               version = 0;
               inputs = [{
                   previousOutpoint = {
                       transactionId = utxos[0].transactionId;
                       index = utxos[0].index;
                   };
                   signatureScript = "";
                   sequence = 0xFFFFFFFFFFFFFFFF;
                   sigOpCount = 1;
               }];
               outputs = [
                   {
                       amount = 10000000;
                       scriptPublicKey = {
                           version = 0;
                           scriptPublicKey = "200099e53094a3fbe8df4fd0db8f92d85f50c3802ede184706de990c46fcdcc503ac";
                       };
                   },
                   {
                       amount = 89990000;
                       scriptPublicKey = {
                           version = 0;
                           scriptPublicKey = "205b7fb28a9e0ef867bcfc85a6400a89bf35ceaada43aa8f7d8e59a1c4f171b8a1ac";
                       };
                   }
               ];
               lockTime = 0;
               subnetworkId = "0000000000000000000000000000000000000000";
               gas = 0;
               payload = "";
           };

           let sighash = calculate_sighash(tx, 0, utxos[0]);
           ?hex_from_array(sighash)
       };

       public func debug_key_derivation(derivation_path: Text) : async ?Text {
            Debug.print("🔑 Debugging key derivation for path: " # derivation_path);
            try {
                Cycles.add<system>(30_000_000_000);
                let pubkey_result = await management_canister.ecdsa_public_key({
                    canister_id = null;
                    derivation_path = []; // Use empty derivation path
                    key_id = { curve = #secp256k1; name = "dfx_test_key" };
                });
                let pubkey = to_compressed_public_key(pubkey_result.public_key);
                Debug.print("   ✅ Public key: " # hex_from_array(pubkey));
                ?hex_from_array(pubkey)
            } catch (err) {
                Debug.print("   ❌ Failed to derive key: " # Error.message(err));
                null
            }
        };

        public func debug_signature_script_parsing(script_hex: Text) : async Text {
            Debug.print("🔍 Parsing signature script: " # script_hex);
            let script_bytes = hex_to_bytes(script_hex);
            
            if (script_bytes.size() < 2) {
                return "Error: Script too short";
            };
            
            let sig_len = Nat8.toNat(script_bytes[0]);
            Debug.print("   📏 Signature length: " # Nat.toText(sig_len));
            
            if (script_bytes.size() < sig_len + 1) {
                return "Error: Script shorter than signature length";
            };
            
            let signature_portion = Array.subArray<Nat8>(script_bytes, 1, sig_len);
            Debug.print("   ✍️ Signature portion: " # hex_from_array(signature_portion));
            Debug.print("   📏 Actual signature portion length: " # Nat.toText(signature_portion.size()));
            
            if (signature_portion.size() > 0) {
                let last_sig_byte = signature_portion[signature_portion.size() - 1];
                Debug.print("   🏷️ Last byte of signature (should be 0x01): 0x" # hex_from_array([last_sig_byte]));
            };
            
            let remaining_start = sig_len + 1;
            if (script_bytes.size() > remaining_start) {
                let pubkey_len = Nat8.toNat(script_bytes[remaining_start]);
                Debug.print("   📏 Public key length: " # Nat.toText(pubkey_len));
                
                if (script_bytes.size() >= remaining_start + 1 + pubkey_len) {
                    let pubkey_portion = Array.subArray<Nat8>(script_bytes, remaining_start + 1, pubkey_len);
                    Debug.print("   🔑 Public key portion: " # hex_from_array(pubkey_portion));
                    Debug.print("   📏 Actual public key portion length: " # Nat.toText(pubkey_portion.size()));
                    
                    if (pubkey_portion.size() > 0) {
                        let last_pubkey_byte = pubkey_portion[pubkey_portion.size() - 1];
                        Debug.print("   🏷️ Last byte of pubkey: 0x" # hex_from_array([last_pubkey_byte]));
                    };
                } else {
                    Debug.print("   ❌ Script shorter than expected for pubkey");
                };
            };
            
            "Parsing complete - check debug output";
        };

    // Modified sign_transaction_input with better debugging
    private func sign_transaction_input_debug(
        tx: KaspaTransaction,
        input_index: Nat,
        utxo: UTXO,
        derivation_path: Text,
        force_72_bytes: Bool
    ) : async ?Text {
        Debug.print("🖌️ Signing input " # Nat.toText(input_index) # "...");
        let sighash = calculate_sighash(tx, input_index, utxo);
        Debug.print("   🔢 Sighash: " # hex_from_array(sighash));
        
        try {
            Cycles.add<system>(30_000_000_000);
            let signature_result = await management_canister.sign_with_ecdsa({
                message_hash = Blob.fromArray(sighash);
                derivation_path = [];
                key_id = { curve = #secp256k1; name = "dfx_test_key" };
            });
            
            let raw_sig = Blob.toArray(signature_result.signature);
            Debug.print("   ✅ Raw signature (64 bytes): " # hex_from_array(raw_sig));
            Debug.print("   📏 Raw signature length: " # Nat.toText(raw_sig.size()));
            
            if (raw_sig.size() != 64) {
                Debug.print("   ❌ Invalid raw signature size");
                return null;
            };
            
            // Get public key
            Cycles.add<system>(30_000_000_000);
            let pubkey_result = await management_canister.ecdsa_public_key({
                canister_id = null;
                derivation_path = [];
                key_id = { curve = #secp256k1; name = "dfx_test_key" };
            });
            
            let compressed_pubkey = to_compressed_public_key(pubkey_result.public_key);
            Debug.print("   ✅ Compressed pubkey (33 bytes): " # hex_from_array(compressed_pubkey));
            Debug.print("   📏 Compressed pubkey length: " # Nat.toText(compressed_pubkey.size()));
            
            // Create signature with SIGHASH_ALL - EXACTLY 65 bytes
            let sig_with_sighash = Array.append<Nat8>(raw_sig, [0x01]);
            Debug.print("   ✅ Signature + SIGHASH_ALL: " # hex_from_array(sig_with_sighash));
            Debug.print("   📏 Sig + SIGHASH_ALL length: " # Nat.toText(sig_with_sighash.size()));
            Debug.print("   🏷️ Last byte (should be 0x01): 0x" # hex_from_array([sig_with_sighash[sig_with_sighash.size() - 1]]));
            
            // Build script: [65][signature+0x01][33][pubkey]
            let script_bytes = Buffer.Buffer<Nat8>(0);
            script_bytes.add(0x41); // 65 in hex
            script_bytes.append(Buffer.fromArray(sig_with_sighash));
            script_bytes.add(0x21); // 33 in hex  
            script_bytes.append(Buffer.fromArray(compressed_pubkey));
            
            let final_script = Buffer.toArray(script_bytes);
            let script_hex = hex_from_array(final_script);
            
            Debug.print("   🔍 FINAL SCRIPT BREAKDOWN:");
            Debug.print("     - Sig length byte: 0x" # hex_from_array([final_script[0]]));
            Debug.print("     - Signature portion (65 bytes): " # hex_from_array(Array.subArray<Nat8>(final_script, 1, 65)));
            Debug.print("     - Pubkey length byte: 0x" # hex_from_array([final_script[66]]));
            Debug.print("     - Pubkey portion (33 bytes): " # hex_from_array(Array.subArray<Nat8>(final_script, 67, 33)));
            Debug.print("     - Total script length: " # Nat.toText(final_script.size()) # " bytes");
            Debug.print("   ✅ Complete SignatureScript: " # script_hex);
            
            ?script_hex
        } catch (err) {
            Debug.print("   ❌ Failed to sign: " # Error.message(err));
            null
        }
    };

    // Test if the UTXO was created with a specific derivation path
    public func find_correct_derivation_path() : async ?Text {
        let target_pubkey = "02219f48df455684794a1a20f8bfc3904365ce55a42d8a1c44541480ba4ed71f61";
        
        let test_paths = [
            "m/44'/111111'/0'/0/0",
            "m/44'/0'/0'/0/0", 
            "m/0'/0'/0'/0'",
            "m/0/0",
            "m/1/0",
            ""  // empty string for empty derivation
        ];
        
        for (path in test_paths.vals()) {
            let derivation = if (path == "") [] else text_to_derivation_path(path);
            
            try {
                Cycles.add<system>(30_000_000_000);
                let result = await management_canister.ecdsa_public_key({
                    canister_id = null;
                    derivation_path = derivation;
                    key_id = { curve = #secp256k1; name = "dfx_test_key" };
                });
                
                let compressed = to_compressed_public_key(result.public_key);
                let hex = hex_from_array(compressed);
                
                Debug.print("Path: " # path # " -> " # hex);
                
                if (hex == target_pubkey) {
                    Debug.print("FOUND MATCH: " # path);
                    return ?path;
                };
            } catch (err) {
                Debug.print("Error with path " # path # ": " # Error.message(err));
            };
        };
        
        null
    };



    public func build_transaction_with_real_utxo(
        recipient: Text,
        amount: Nat64,
        fee: Nat64
    ) : async ?TransactionRequest {
        Debug.print("🏗️ Building Kaspa transaction with real UTXO...");
        Debug.print("   📫 Recipient: " # recipient);
        Debug.print("   💰 Amount: " # Nat64.toText(amount) # " sompi");
        Debug.print("   💸 Fee: " # Nat64.toText(fee) # " sompi");

        // Your actual UTXO from the API
        let utxos : [UTXO] = [{
            transactionId = "75b23c8a72ed66a1a9b0111a609b20314a9fe873785ab931cec1b3846e0eeafd";
            index = 1;
            amount = 400000000; // 4 KAS
            scriptPublicKey = "210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab";
            scriptVersion = 0;
            address = "kaspa:qypff6urmgk8452vjx55r63dhc38s6ewlavknmnefzgac42n3lt8cdchp86su6n";
        }];

        let total_in : Nat64 = utxos[0].amount;
        if (total_in < amount + fee) {
            Debug.print("   ❌ Insufficient funds: " # Nat64.toText(total_in) # " < " # Nat64.toText(amount + fee));
            return null;
        };

        let change = total_in - amount - fee;
        Debug.print("   🔄 Change: " # Nat64.toText(change) # " sompi");

        // Recipient script - you'll need to convert the address to scriptPubKey
        // For now, using a placeholder - you'd need to decode the recipient address
        let recipient_script_hex = "2000" # Text.replace(recipient, #text("kaspa:"), "") # "ac"; // This needs proper address decoding
        
        // For your change, use your own public key
        let change_script = hex_to_bytes("210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ac");

        let tx : KaspaTransaction = {
            version = 0;
            inputs = [{
                previousOutpoint = {
                    transactionId = utxos[0].transactionId;
                    index = utxos[0].index;
                };
                signatureScript = "";
                sequence = 0xFFFFFFFFFFFFFFFF;
                sigOpCount = 1;
            }];
            outputs = [
                {
                    amount = amount;
                    scriptPublicKey = {
                        version = 0;
                        scriptPublicKey = "205b7fb28a9e0ef867bcfc85a6400a89bf35ceaada43aa8f7d8e59a1c4f171b8a1ac"; // You need to decode the recipient address
                    };
                },
                {
                    amount = change;
                    scriptPublicKey = {
                        version = 0;
                        scriptPublicKey = hex_from_array(change_script);
                    };
                }
            ];
            lockTime = 0;
            subnetworkId = "0000000000000000000000000000000000000000";
            gas = 0;
            payload = "";
        };

        // First verify your public key matches the UTXO
        try {
            Cycles.add<system>(30_000_000_000);
            let pubkey_result = await management_canister.ecdsa_public_key({
                canister_id = null;
                derivation_path = []; // Use whatever derivation path generated your UTXO
                key_id = { curve = #secp256k1; name = "dfx_test_key" };
            });
            
            let compressed_pubkey = to_compressed_public_key(pubkey_result.public_key);
            let expected_pubkey = "0294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37";
            let actual_pubkey = hex_from_array(compressed_pubkey);
            
            Debug.print("   🔍 Expected pubkey: " # expected_pubkey);
            Debug.print("   🔍 Actual pubkey: " # actual_pubkey);
            
            if (actual_pubkey != expected_pubkey) {
                Debug.print("   ❌ Public key mismatch! Cannot spend this UTXO.");
                return null;
            };
            
            Debug.print("   ✅ Public key matches UTXO!");
            
        } catch (err) {
            Debug.print("   ❌ Failed to verify public key: " # Error.message(err));
            return null;
        };

        // Continue with signing...
        if (not validate_transaction(tx, utxos)) {
            Debug.print("   ❌ Transaction validation failed");
            return null;
        };

        switch (await sign_transaction_input(tx, 0, utxos[0], "", false)) {
            case (null) {
                Debug.print("   ❌ Failed to sign input 0");
                null
            };
            case (?signature_script) {
                Debug.print("   ✅ Signed input 0");
                let signed_tx : KaspaTransaction = {
                    version = tx.version;
                    inputs = [{
                        previousOutpoint = tx.inputs[0].previousOutpoint;
                        signatureScript = signature_script;
                        sequence = tx.inputs[0].sequence;
                        sigOpCount = tx.inputs[0].sigOpCount;
                    }];
                    outputs = tx.outputs;
                    lockTime = tx.lockTime;
                    subnetworkId = tx.subnetworkId;
                    gas = tx.gas;
                    payload = tx.payload;
                };

                Debug.print("   🎉 Transaction built and signed successfully!");
                ?{
                    transaction = signed_tx;
                    allowOrphan = false;
                }
            }
        }
    };

    // Helper function to test which derivation path generated your UTXO
    public func verify_utxo_key_match() : async Bool {
        let expected_pubkey = "0294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37";
        
        try {
            Cycles.add<system>(30_000_000_000);
            let pubkey_result = await management_canister.ecdsa_public_key({
                canister_id = null;
                derivation_path = []; // Test with empty path first
                key_id = { curve = #secp256k1; name = "dfx_test_key" };
            });
            
            let compressed_pubkey = to_compressed_public_key(pubkey_result.public_key);
            let actual_pubkey = hex_from_array(compressed_pubkey);
            
            Debug.print("Expected: " # expected_pubkey);
            Debug.print("Actual: " # actual_pubkey);
            
            actual_pubkey == expected_pubkey
        } catch (err) {
            Debug.print("Error: " # Error.message(err));
            false
        }
    };



    private func sign_transaction_input_p2pk_fixed(
  tx: KaspaTransaction,
  input_index: Nat,
  utxo: UTXO,
  derivation_path: Text,
  force_72_bytes: Bool
) : async ?Text {
  Debug.print("🖌️ Signing input " # Nat.toText(input_index) # " with P2PK fix...");
  let sighash = calculate_sighash(tx, input_index, utxo);
  Debug.print(" 🔢 Sighash: " # hex_from_array(sighash));
  if (sighash.size() != 32) {
    Debug.print(" ❌ Invalid sighash size: " # Nat.toText(sighash.size()));
    return null;
  };

  try {
    Cycles.add<system>(30_000_000_000);
    let signature_result = await management_canister.sign_with_ecdsa({
      message_hash = Blob.fromArray(sighash);
      derivation_path = []; // Empty for dfx_test_key
      key_id = { curve = #secp256k1; name = "dfx_test_key" };
    });
    
    let raw_sig = Blob.toArray(signature_result.signature);
    if (raw_sig.size() != 64) {
      Debug.print(" ❌ Invalid raw signature size: " # Nat.toText(raw_sig.size()));
      return null;
    };
    Debug.print(" ✅ Raw signature: " # hex_from_array(raw_sig));
    
    let der_sig = der_encode_signature(raw_sig, force_72_bytes);
    if (der_sig.size() < 70 or der_sig.size() > 72 or der_sig[0] != 0x30) {
      Debug.print(" ❌ Invalid DER signature: length=" # Nat.toText(der_sig.size()) # ", hex=" # hex_from_array(der_sig));
      return null;
    };
    Debug.print(" ✅ DER signature: " # hex_from_array(der_sig));
    
    let sig_with_sighash = Array.append<Nat8>(der_sig, [0x01]);
    let sig_len = Nat8.fromNat(sig_with_sighash.size());
    let script_bytes = Buffer.Buffer<Nat8>(0);
    script_bytes.add(sig_len);
    script_bytes.append(Buffer.fromArray(sig_with_sighash));
    
    let script_hex = hex_from_array(Buffer.toArray(script_bytes));
    Debug.print(" ✅ SignatureScript: " # script_hex);
    Debug.print(" 🔍 Breakdown: [" # hex_from_array([sig_len]) # "][" # hex_from_array(sig_with_sighash) # "]");
    
    // For off-chain verification
    Debug.print(" 🔍 For verification:");
    Debug.print("   - Public key: 0294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37");
    Debug.print("   - Sighash: " # hex_from_array(sighash));
    Debug.print("   - Signature: " # hex_from_array(der_sig));
    
    ?script_hex
  } catch (err) {
    Debug.print(" ❌ Failed to sign input: " # Error.message(err));
    return null;
  }
};

    public func build_transaction_p2pk_fix(
  recipient: Text,
  amount: Nat64,
  fee: Nat64
) : async ?TransactionRequest {
  Debug.print("🏗️ Building P2PK transaction with fix...");

  // Verify key match first
  let key_match = await verify_utxo_key_match();
  if (not key_match) {
    Debug.print(" ❌ Public key does not match UTXO");
    return null;
  };

  let utxos : [UTXO] = [{
    transactionId = "75b23c8a72ed66a1a9b0111a609b20314a9fe873785ab931cec1b3846e0eeafd";
    index = 1;
    amount = 400000000; // 4 KAS
    scriptPublicKey = "210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab";
    scriptVersion = 0;
    address = "kaspa:qypff6urmgk8452vjx55r63dhc38s6ewlavknmnefzgac42n3lt8cdchp86su6n";
  }];
  let total_in : Nat64 = utxos[0].amount;
  if (total_in < amount + fee) {
    Debug.print(" ❌ Insufficient funds: " # Nat64.toText(total_in) # " < " # Nat64.toText(amount + fee));
    return null;
  };
  let change = total_in - amount - fee;
  Debug.print(" 🔄 Change: " # Nat64.toText(change) # " sompi");

  // Decode recipient address
  switch (Address.decode_address(recipient)) {
    case (? (addr_type, payload)) {
      let recipient_script_hex = if (addr_type == Address.ECDSA) {
        "21" # hex_from_array(payload) # "ab"
      } else if (addr_type == Address.SCHNORR) {
        "20" # hex_from_array(payload) # "ac"
      } else if (addr_type == Address.P2SH) {
        "a914" # hex_from_array(payload) # "87"
      } else {
        Debug.print("Unsupported address type: " # Nat.toText(addr_type));
        return null;
      };
      Debug.print(" ✅ Recipient scriptPublicKey: " # recipient_script_hex);
      let recipient_script = hex_to_bytes(recipient_script_hex);

      // Change script - ECDSA P2PK
      let change_script = hex_to_bytes("210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab");

      let tx : KaspaTransaction = {
        version = 0;
        inputs = [{
          previousOutpoint = {
            transactionId = utxos[0].transactionId;
            index = utxos[0].index;
          };
          signatureScript = "";
          sequence = 0xFFFFFFFFFFFFFFFF;
          sigOpCount = 1;
        }];
        outputs = [
          {
            amount = amount;
            scriptPublicKey = {
              version = 0; // Correct for transaction output
              scriptPublicKey = hex_from_array(recipient_script);
            };
          },
          {
            amount = change;
            scriptPublicKey = {
              version = 0; // Correct for transaction output
              scriptPublicKey = hex_from_array(change_script);
            };
          }
        ];
        lockTime = 0;
        subnetworkId = "0000000000000000000000000000000000000000";
        gas = 0;
        payload = "";
      };
      if (not validate_transaction(tx, utxos)) {
        Debug.print(" ❌ Transaction validation failed");
        return null;
      };
      switch (await sign_transaction_input_p2pk_fixed(tx, 0, utxos[0], "", true)) {
        case (null) {
          Debug.print(" ❌ Failed to sign input 0");
          null
        };
        case (?signature_script) {
          Debug.print(" ✅ Signed input 0");
          //await debug_signature_script_parsing(signature_script);
          let signed_tx : KaspaTransaction = {
            version = tx.version;
            inputs = [{
              previousOutpoint = tx.inputs[0].previousOutpoint;
              signatureScript = signature_script;
              sequence = tx.inputs[0].sequence;
              sigOpCount = tx.inputs[0].sigOpCount;
            }];
            outputs = tx.outputs;
            lockTime = tx.lockTime;
            subnetworkId = tx.subnetworkId;
            gas = tx.gas;
            payload = tx.payload;
          };
          Debug.print(" 🎉 P2PK Transaction ready!");
          ?{
            transaction = signed_tx;
            allowOrphan = false;
          }
        }
      }
    };
    case null {
      Debug.print("Failed to decode recipient address");
      return null;
    };
  };
};

    // Test function
    public func test_p2pk_fix() : async ?Text {
        Debug.print("🧪 Testing P2PK signature script fix...");
        
        switch (await build_transaction_p2pk_der_fixed(//build_transaction_p2pk_fix(
            "kaspa:qpdhlv52nc80seauljz6vsq23xlntn42mfp64rma3ev6r383wxu2z8kakh68k",
            10000000,  // 0.1 KAS
            10000      // 0.0001 KAS fee
        )) {
            case (?request) {
                let json = transaction_request_to_json(request);
                Debug.print("✅ P2PK transaction JSON: " # json);
                ?json
            };
            case null {
                Debug.print("❌ P2PK fix failed");
                null
            };
        };
    };



// Test function to decode a single Kaspa address
public func test_decode_kaspa_address(address: Text) : async () {
  Debug.print("🧪 Testing decode_address for: " # address);

  switch (Address.decode_address(address)) {
    case (null) {
      Debug.print(" ❌ Failed to decode address");
    };
    case (? (addr_type, payload)) {
      let type_name = if (addr_type == Address.SCHNORR) { "SCHNORR" }
                      else if (addr_type == Address.ECDSA) { "ECDSA" }
                      else if (addr_type == Address.P2SH) { "P2SH" }
                      else { "Unknown" };
      Debug.print(" ✅ Decoded address:");
      Debug.print("   - Type: " # Nat.toText(addr_type) # " (" # type_name # ")");
      Debug.print("   - Payload (hex): " # hex_from_array(payload));
      Debug.print("   - Payload length: " # Nat.toText(payload.size()));

      // Construct scriptPublicKey
      let script_hex = if (addr_type == Address.ECDSA) {
        "21" # hex_from_array(payload) # "ab"
      } else if (addr_type == Address.SCHNORR) {
        "20" # hex_from_array(payload) # "ac"
      } else if (addr_type == Address.P2SH) {
        "a914" # hex_from_array(payload) # "87"
      } else {
        "";
      };
      if (script_hex != "") {
        Debug.print(" ✅ scriptPublicKey: " # script_hex);
      } else {
        Debug.print(" ❌ Unsupported address type for scriptPublicKey");
      };
    };
  };
  Debug.print("🧪 Test completed.");
};


// Fixed signing function for Kaspa P2PK transactions (no DER encoding)
// Fixed signing function for Kaspa P2PK transactions (no DER encoding)
private func sign_transaction_input_p2pk_raw(
    tx: KaspaTransaction,
    input_index: Nat,
    utxo: UTXO,
    derivation_path: Text,
    force_72_bytes: Bool
) : async ?Text {
    Debug.print("🖌️ Signing P2PK input " # Nat.toText(input_index) # " with raw signature...");
    let sighash = calculate_sighash(tx, input_index, utxo);
    Debug.print("   🔢 Sighash: " # hex_from_array(sighash));
    
    if (sighash.size() != 32) {
        Debug.print("   ❌ Invalid sighash size: " # Nat.toText(sighash.size()));
        return null;
    };
    
    try {
        Cycles.add<system>(30_000_000_000);
        let signature_result = await management_canister.sign_with_ecdsa({
            message_hash = Blob.fromArray(sighash);
            derivation_path = []; // Empty for dfx_test_key
            key_id = { curve = #secp256k1; name = "dfx_test_key" };
        });
        
        let raw_sig = Blob.toArray(signature_result.signature);
        if (raw_sig.size() != 64) {
            Debug.print("   ❌ Invalid raw signature size: " # Nat.toText(raw_sig.size()));
            return null;
        };
        
        Debug.print("   ✅ Raw signature (64 bytes): " # hex_from_array(raw_sig));
        
        // For P2PK: Use RAW signature (64 bytes) + SIGHASH_ALL (1 byte) = 65 bytes total
        let sig_with_sighash = Array.append<Nat8>(raw_sig, [0x01]);
        Debug.print("   ✅ Signature + SIGHASH_ALL (65 bytes): " # hex_from_array(sig_with_sighash));
        
        // P2PK signature script: [65][raw_signature_with_sighash]
        let sig_len = Nat8.fromNat(sig_with_sighash.size()); // Should be 65 (0x41)
        let script_bytes = Buffer.Buffer<Nat8>(0);
        script_bytes.add(sig_len);
        script_bytes.append(Buffer.fromArray(sig_with_sighash));
        
        let script_hex = hex_from_array(Buffer.toArray(script_bytes));
        Debug.print("   ✅ P2PK SignatureScript: " # script_hex);
        Debug.print("   🔍 Breakdown: [0x" # hex_from_array([sig_len]) # "][" # hex_from_array(sig_with_sighash) # "]");
        Debug.print("   📏 Total script length: " # Nat.toText(Buffer.toArray(script_bytes).size()) # " bytes");
        
        ?script_hex
    } catch (err) {
        Debug.print("   ❌ Failed to sign input: " # Error.message(err));
        null
    }
};

// Updated transaction builder using raw signatures for P2PK
public func build_transaction_p2pk_raw(
    recipient: Text,
    amount: Nat64,
    fee: Nat64
) : async ?TransactionRequest {
    Debug.print("🏗️ Building P2PK transaction with RAW signatures...");
    
    // Verify key match first
    let key_match = await verify_utxo_key_match();
    if (not key_match) {
        Debug.print("   ❌ Public key does not match UTXO");
        return null;
    };
    
    let utxos : [UTXO] = [{
        transactionId = "75b23c8a72ed66a1a9b0111a609b20314a9fe873785ab931cec1b3846e0eeafd";
        index = 1;
        amount = 400000000; // 4 KAS
        scriptPublicKey = "210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab";
        scriptVersion = 0;
        address = "kaspa:qypff6urmgk8452vjx55r63dhc38s6ewlavknmnefzgac42n3lt8cdchp86su6n";
    }];
    
    let total_in : Nat64 = utxos[0].amount;
    if (total_in < amount + fee) {
        Debug.print("   ❌ Insufficient funds: " # Nat64.toText(total_in) # " < " # Nat64.toText(amount + fee));
        return null;
    };
    
    let change = total_in - amount - fee;
    Debug.print("   🔄 Change: " # Nat64.toText(change) # " sompi");
    
    // Decode recipient address
    switch (Address.decode_address(recipient)) {
        case (? (addr_type, payload)) {
            let recipient_script_hex = if (addr_type == Address.ECDSA) {
                "21" # hex_from_array(payload) # "ab"
            } else if (addr_type == Address.SCHNORR) {
                "20" # hex_from_array(payload) # "ac"
            } else if (addr_type == Address.P2SH) {
                "a914" # hex_from_array(payload) # "87"
            } else {
                Debug.print("   ❌ Unsupported address type: " # Nat.toText(addr_type));
                return null;
            };
            
            Debug.print("   ✅ Recipient scriptPublicKey: " # recipient_script_hex);
            let recipient_script = hex_to_bytes(recipient_script_hex);
            
            // Change script - ECDSA P2PK (same as input)
            let change_script = hex_to_bytes("210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab");
            
            let tx : KaspaTransaction = {
                version = 0;
                inputs = [{
                    previousOutpoint = {
                        transactionId = utxos[0].transactionId;
                        index = utxos[0].index;
                    };
                    signatureScript = "";
                    sequence = 0xFFFFFFFFFFFFFFFF;
                    sigOpCount = 1;
                }];
                outputs = [
                    {
                        amount = amount;
                        scriptPublicKey = {
                            version = 0;
                            scriptPublicKey = hex_from_array(recipient_script);
                        };
                    },
                    {
                        amount = change;
                        scriptPublicKey = {
                            version = 0;
                            scriptPublicKey = hex_from_array(change_script);
                        };
                    }
                ];
                lockTime = 0;
                subnetworkId = "0000000000000000000000000000000000000000";
                gas = 0;
                payload = "";
            };
            
            if (not validate_transaction(tx, utxos)) {
                Debug.print("   ❌ Transaction validation failed");
                return null;
            };
            
            switch (await sign_transaction_input_p2pk_raw(tx, 0, utxos[0], "", false)) {
                case (null) {
                    Debug.print("   ❌ Failed to sign input 0");
                    null
                };
                case (?signature_script) {
                    Debug.print("   ✅ Signed input 0 with raw signature");
                    
                    let signed_tx : KaspaTransaction = {
                        version = tx.version;
                        inputs = [{
                            previousOutpoint = tx.inputs[0].previousOutpoint;
                            signatureScript = signature_script;
                            sequence = tx.inputs[0].sequence;
                            sigOpCount = tx.inputs[0].sigOpCount;
                        }];
                        outputs = tx.outputs;
                        lockTime = tx.lockTime;
                        subnetworkId = tx.subnetworkId;
                        gas = tx.gas;
                        payload = tx.payload;
                    };
                    
                    Debug.print("   🎉 P2PK Transaction ready with RAW signature!");
                    ?{
                        transaction = signed_tx;
                        allowOrphan = false;
                    }
                }
            }
        };
        case null {
            Debug.print("   ❌ Failed to decode recipient address");
            return null;
        };
    };
};

// Test function for raw signature approach
public func test_p2pk_raw() : async ?Text {
    Debug.print("🧪 Testing P2PK with RAW signatures...");
    
    switch (await build_transaction_p2pk_raw(
        "kaspa:qpdhlv52nc80seauljz6vsq23xlntn42mfp64rma3ev6r383wxu2z8kakh68k",
        10000000,  // 0.1 KAS
        10000      // 0.0001 KAS fee
    )) {
        case (?request) {
            let json = transaction_request_to_json(request);
            Debug.print("✅ P2PK RAW transaction JSON: " # json);
            ?json
        };
        case null {
            Debug.print("❌ P2PK RAW transaction failed");
            null
        };
    };
};

// Debug function to trace sighash calculation step by step
public func debug_sighash_detailed(
    recipient: Text,
    amount: Nat64,
    fee: Nat64
) : async ?Text {
    Debug.print("🔍 DETAILED SIGHASH DEBUG");
    
    let utxos : [UTXO] = [{
        transactionId = "75b23c8a72ed66a1a9b0111a609b20314a9fe873785ab931cec1b3846e0eeafd";
        index = 1;
        amount = 400000000;
        scriptPublicKey = "210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab";
        scriptVersion = 0;
        address = "kaspa:qypff6urmgk8452vjx55r63dhc38s6ewlavknmnefzgac42n3lt8cdchp86su6n";
    }];
    
    let change = utxos[0].amount - amount - fee;
    
    // Build the exact same transaction
    switch (Address.decode_address(recipient)) {
        case (? (addr_type, payload)) {
            let recipient_script_hex = if (addr_type == Address.SCHNORR) {
                "20" # hex_from_array(payload) # "ac"
            } else if (addr_type == Address.ECDSA) {
                "21" # hex_from_array(payload) # "ab"
            } else {
                Debug.print("Unsupported address type");
                return null;
            };
            
            let recipient_script = hex_to_bytes(recipient_script_hex);
            let change_script = hex_to_bytes("210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab");
            
            let tx : KaspaTransaction = {
                version = 0;
                inputs = [{
                    previousOutpoint = {
                        transactionId = utxos[0].transactionId;
                        index = utxos[0].index;
                    };
                    signatureScript = "";
                    sequence = 0xFFFFFFFFFFFFFFFF;
                    sigOpCount = 1;
                }];
                outputs = [
                    {
                        amount = amount;
                        scriptPublicKey = {
                            version = 0;
                            scriptPublicKey = hex_from_array(recipient_script);
                        };
                    },
                    {
                        amount = change;
                        scriptPublicKey = {
                            version = 0;
                            scriptPublicKey = hex_from_array(change_script);
                        };
                    }
                ];
                lockTime = 0;
                subnetworkId = "0000000000000000000000000000000000000000";
                gas = 0;
                payload = "";
            };
            
            Debug.print("📋 Transaction Details:");
            Debug.print("  Version: " # Nat.toText(tx.version));
            Debug.print("  Input TxID: " # tx.inputs[0].previousOutpoint.transactionId);
            Debug.print("  Input Index: " # Nat32.toText(tx.inputs[0].previousOutpoint.index));
            Debug.print("  Input Sequence: " # Nat64.toText(tx.inputs[0].sequence));
            Debug.print("  Input SigOpCount: " # Nat8.toText(tx.inputs[0].sigOpCount));
            Debug.print("  Output 0 Amount: " # Nat64.toText(tx.outputs[0].amount));
            Debug.print("  Output 0 Script: " # tx.outputs[0].scriptPublicKey.scriptPublicKey);
            Debug.print("  Output 1 Amount: " # Nat64.toText(tx.outputs[1].amount));
            Debug.print("  Output 1 Script: " # tx.outputs[1].scriptPublicKey.scriptPublicKey);
            Debug.print("  LockTime: " # Nat64.toText(tx.lockTime));
            Debug.print("  SubnetworkID: " # tx.subnetworkId);
            Debug.print("  Gas: " # Nat64.toText(tx.gas));
            Debug.print("  Payload: " # tx.payload);
            
            Debug.print("📋 UTXO Details:");
            Debug.print("  UTXO TxID: " # utxos[0].transactionId);
            Debug.print("  UTXO Index: " # Nat32.toText(utxos[0].index));
            Debug.print("  UTXO Amount: " # Nat64.toText(utxos[0].amount));
            Debug.print("  UTXO ScriptPubKey: " # utxos[0].scriptPublicKey);
            Debug.print("  UTXO ScriptVersion: " # Nat.toText(utxos[0].scriptVersion));
            
            let sighash = calculate_sighash_detailed(tx, 0, utxos[0]);
            ?hex_from_array(sighash)
        };
        case null {
            Debug.print("Failed to decode address");
            null
        };
    };
};



// Enhanced sighash calculation with more detailed logging (VIERIFIED WITH GROK PYTHON)
private func calculate_sighash_detailed(tx: KaspaTransaction, input_index: Nat, utxo: UTXO) : [Nat8] {
    Debug.print("🔢 DETAILED SIGHASH CALCULATION for input " # Nat.toText(input_index));
    let preimage = Buffer.Buffer<Nat8>(0);

    // 1. Version (2 bytes, little-endian)
    let version_bytes = nat_to_le_bytes(tx.version, 2);
    preimage.append(Buffer.fromArray(version_bytes));
    Debug.print("  1. Version: " # Nat.toText(tx.version) # " -> " # hex_from_array(version_bytes));

    // 2. PreviousOutputsHash
    let prevouts = Buffer.Buffer<Nat8>(0);
    for (input in tx.inputs.vals()) {
        let txid_bytes = hex_to_bytes(input.previousOutpoint.transactionId);
        let index_bytes = nat32_to_bytes(input.previousOutpoint.index);
        prevouts.append(Buffer.fromArray(txid_bytes));
        prevouts.append(Buffer.fromArray(index_bytes));
        Debug.print("    Prevout: " # input.previousOutpoint.transactionId # ":" # Nat32.toText(input.previousOutpoint.index));
        Debug.print("    TxID bytes: " # hex_from_array(txid_bytes));
        Debug.print("    Index bytes: " # hex_from_array(index_bytes));
    };
    let prevouts_bytes = Buffer.toArray(prevouts);
    let prevouts_hash = Blake2b.hash(Blob.fromArray(prevouts_bytes), ?{ digest_length = 32; key = null; salt = null; personal = null });
    preimage.append(Buffer.fromArray(Blob.toArray(prevouts_hash)));
    Debug.print("  2. PreviousOutputsHash: " # hex_from_array(Blob.toArray(prevouts_hash)));

    // 3. SequencesHash
    let sequences = Buffer.Buffer<Nat8>(0);
    for (input in tx.inputs.vals()) {
        let seq_bytes = nat64_to_le_bytes(input.sequence);
        sequences.append(Buffer.fromArray(seq_bytes));
        Debug.print("    Sequence: " # Nat64.toText(input.sequence) # " -> " # hex_from_array(seq_bytes));
    };
    let sequences_bytes = Buffer.toArray(sequences);
    let sequences_hash = Blake2b.hash(Blob.fromArray(sequences_bytes), ?{ digest_length = 32; key = null; salt = null; personal = null });
    preimage.append(Buffer.fromArray(Blob.toArray(sequences_hash)));
    Debug.print("  3. SequencesHash: " # hex_from_array(Blob.toArray(sequences_hash)));

    // 4. SigOpCountsHash
    let sigopcounts = Buffer.Buffer<Nat8>(0);
    for (input in tx.inputs.vals()) {
        sigopcounts.add(input.sigOpCount);
        Debug.print("    SigOpCount: " # Nat8.toText(input.sigOpCount));
    };
    let sigopcounts_bytes = Buffer.toArray(sigopcounts);
    let sigopcounts_hash = Blake2b.hash(Blob.fromArray(sigopcounts_bytes), ?{ digest_length = 32; key = null; salt = null; personal = null });
    preimage.append(Buffer.fromArray(Blob.toArray(sigopcounts_hash)));
    Debug.print("  4. SigOpCountsHash: " # hex_from_array(Blob.toArray(sigopcounts_hash)));

    // 5. Current input details
    let input = tx.inputs[input_index];
    let txid_bytes = hex_to_bytes(input.previousOutpoint.transactionId);
    let index_bytes = nat32_to_bytes(input.previousOutpoint.index); // Fixed: Use nat32_to_bytes
    preimage.append(Buffer.fromArray(txid_bytes));
    preimage.append(Buffer.fromArray(index_bytes));
    Debug.print("  5. Input TxID: " # input.previousOutpoint.transactionId);
    Debug.print("     Input Index: " # Nat32.toText(input.previousOutpoint.index) # " -> " # hex_from_array(index_bytes));

    // 6. Script version (2 bytes, little-endian)
    let script_version_bytes = nat_to_le_bytes(utxo.scriptVersion, 2);
    preimage.append(Buffer.fromArray(script_version_bytes));
    Debug.print("  6. Script Version: " # Nat.toText(utxo.scriptVersion) # " -> " # hex_from_array(script_version_bytes));

    // 7. ScriptPubKey with length prefix
    let script_bytes = hex_to_bytes(utxo.scriptPublicKey);
    let script_len = Nat8.fromNat(script_bytes.size());
    preimage.add(script_len);
    preimage.append(Buffer.fromArray(script_bytes));
    Debug.print("  7. ScriptPubKey Length: " # Nat.toText(script_bytes.size()) # " -> " # hex_from_array([script_len]));
    Debug.print("     ScriptPubKey: " # utxo.scriptPublicKey);
    Debug.print("     ScriptPubKey bytes: " # hex_from_array(script_bytes));

    // 8. Amount (8 bytes, little-endian)
    let amount_bytes = nat64_to_le_bytes(utxo.amount);
    preimage.append(Buffer.fromArray(amount_bytes));
    Debug.print("  8. Amount: " # Nat64.toText(utxo.amount) # " -> " # hex_from_array(amount_bytes));

    // 9. Sequence (8 bytes, little-endian)
    let sequence_bytes = nat64_to_le_bytes(input.sequence);
    preimage.append(Buffer.fromArray(sequence_bytes));
    Debug.print("  9. Sequence: " # Nat64.toText(input.sequence) # " -> " # hex_from_array(sequence_bytes));

    // 10. SigOpCount (1 byte)
    preimage.add(input.sigOpCount);
    Debug.print(" 10. SigOpCount: " # Nat8.toText(input.sigOpCount) # " -> " # hex_from_array([input.sigOpCount]));

    // 11. OutputsHash
    let outputs = Buffer.Buffer<Nat8>(0);
    for (output in tx.outputs.vals()) {
        let amount_bytes = nat64_to_le_bytes(output.amount);
        let version_bytes = nat_to_le_bytes(output.scriptPublicKey.version, 2); // Fixed: Use nat_to_le_bytes
        let script_bytes = hex_to_bytes(output.scriptPublicKey.scriptPublicKey);
        let script_len = Nat8.fromNat(script_bytes.size());
        
        outputs.append(Buffer.fromArray(amount_bytes));
        outputs.append(Buffer.fromArray(version_bytes));
        outputs.add(script_len);
        outputs.append(Buffer.fromArray(script_bytes));
        
        Debug.print("    Output Amount: " # Nat64.toText(output.amount) # " -> " # hex_from_array(amount_bytes));
        Debug.print("    Output Version: " # Nat.toText(output.scriptPublicKey.version) # " -> " # hex_from_array(version_bytes));
        Debug.print("    Output Script: " # output.scriptPublicKey.scriptPublicKey);
        Debug.print("    Output Script Length: " # Nat.toText(script_bytes.size()) # " -> " # hex_from_array([script_len]));
    };
    let outputs_bytes = Buffer.toArray(outputs);
    let outputs_hash = Blake2b.hash(Blob.fromArray(outputs_bytes), ?{ digest_length = 32; key = null; salt = null; personal = null });
    preimage.append(Buffer.fromArray(Blob.toArray(outputs_hash)));
    Debug.print(" 11. OutputsHash: " # hex_from_array(Blob.toArray(outputs_hash)));

    // 12. LockTime (8 bytes, little-endian)
    let locktime_bytes = nat64_to_le_bytes(tx.lockTime);
    preimage.append(Buffer.fromArray(locktime_bytes));
    Debug.print(" 12. LockTime: " # Nat64.toText(tx.lockTime) # " -> " # hex_from_array(locktime_bytes));

    // 13. SubnetworkID (20 bytes)
    let subnetwork_bytes = hex_to_bytes(tx.subnetworkId);
    preimage.append(Buffer.fromArray(subnetwork_bytes));
    Debug.print(" 13. SubnetworkID: " # tx.subnetworkId # " -> " # hex_from_array(subnetwork_bytes));

    // 14. Gas (8 bytes, little-endian)
    let gas_bytes = nat64_to_le_bytes(tx.gas);
    preimage.append(Buffer.fromArray(gas_bytes));
    Debug.print(" 14. Gas: " # Nat64.toText(tx.gas) # " -> " # hex_from_array(gas_bytes));

    // 15. PayloadHash
    let payload_bytes = hex_to_bytes(tx.payload);
    let payload_hash = Blake2b.hash(Blob.fromArray(payload_bytes), ?{ digest_length = 32; key = null; salt = null; personal = null });
    preimage.append(Buffer.fromArray(Blob.toArray(payload_hash)));
    Debug.print(" 15. Payload: " # tx.payload);
    Debug.print("     PayloadHash: " # hex_from_array(Blob.toArray(payload_hash)));

    // 16. SighashType (1 byte)
    let sighash_type = [0x01 : Nat8]; // SIGHASH_ALL
    preimage.append(Buffer.fromArray(sighash_type));
    Debug.print(" 16. SighashType: " # hex_from_array(sighash_type));

    let final_preimage = Buffer.toArray(preimage);
    Debug.print(" 🔢 Final preimage (" # Nat.toText(final_preimage.size()) # " bytes): " # hex_from_array(final_preimage));
    
    let final_hash = Blake2b.hash(Blob.fromArray(final_preimage), ?{ digest_length = 32; key = null; salt = null; personal = null });
    let hash_bytes = Blob.toArray(final_hash);
    Debug.print(" 🎯 Final sighash: " # hex_from_array(hash_bytes));
    Debug.print(" 📏 Sighash length: " # Nat.toText(hash_bytes.size()) # " bytes");
    
    hash_bytes
};

// Test the detailed sighash
public func test_sighash_debug() : async ?Text {
    await debug_sighash_detailed(
        "kaspa:qpdhlv52nc80seauljz6vsq23xlntn42mfp64rma3ev6r383wxu2z8kakh68k",
        10000000,  // 0.1 KAS
        10000      // 0.0001 KAS fee
    )
};











private func sign_transaction_input_p2pk_der(
    tx: KaspaTransaction,
    input_index: Nat,
    utxo: UTXO,
    derivation_path: Text,
    force_72_bytes: Bool
) : async ?Text {
    Debug.print("🖌️ Signing P2PK input " # Nat.toText(input_index) # " with DER encoding...");
    let sighash = calculate_sighash(tx, input_index, utxo);
    Debug.print("   🔢 Sighash: " # hex_from_array(sighash));
    
    if (sighash.size() != 32) {
        Debug.print("   ❌ Invalid sighash size: " # Nat.toText(sighash.size()));
        return null;
    };
    
    try {
        Cycles.add<system>(30_000_000_000);
        let signature_result = await management_canister.sign_with_ecdsa({
            message_hash = Blob.fromArray(sighash);
            derivation_path = []; // Empty for dfx_test_key
            key_id = { curve = #secp256k1; name = "dfx_test_key" };
        });
        
        let raw_sig = Blob.toArray(signature_result.signature);
        if (raw_sig.size() != 64) {
            Debug.print("   ❌ Invalid raw signature size: " # Nat.toText(raw_sig.size()));
            return null;
        };
        
        Debug.print("   ✅ Raw signature (64 bytes): " # hex_from_array(raw_sig));
        
        // Convert raw signature to DER format
        let der_sig = der_encode_signature_fixed(raw_sig);
        if (der_sig.size() == 0) {
            Debug.print("   ❌ DER encoding failed");
            return null;
        };
        
        Debug.print("   ✅ DER signature (" # Nat.toText(der_sig.size()) # " bytes): " # hex_from_array(der_sig));
        
        // P2PK signature script format: [actual_sig_len][der_signature + sighash_flag]
        let sig_with_sighash = Array.append<Nat8>(der_sig, [0x01]);
        let actual_sig_len = Nat8.fromNat(sig_with_sighash.size()); // Use actual length, not fixed 72
        
        Debug.print("   ✅ Signature + SIGHASH_ALL (" # Nat.toText(sig_with_sighash.size()) # " bytes): " # hex_from_array(sig_with_sighash));
        
        let script_bytes = Buffer.Buffer<Nat8>(0);
        script_bytes.add(actual_sig_len);                            // Use actual signature length
        script_bytes.append(Buffer.fromArray<Nat8>(sig_with_sighash)); // DER signature + SIGHASH_ALL
        
        let script_hex = hex_from_array(Buffer.toArray(script_bytes));
        Debug.print("   ✅ P2PK SignatureScript: " # script_hex);
        Debug.print("   🔍 Breakdown: [0x" # hex_from_array([actual_sig_len]) # "][" # hex_from_array(sig_with_sighash) # "]");
        Debug.print("   📏 Total script length: " # Nat.toText(Buffer.toArray(script_bytes).size()) # " bytes");
        
        ?script_hex
    } catch (err) {
        Debug.print("   ❌ Failed to sign input: " # Error.message(err));
        null
    }
};

// Fixed DER encoding function
private func der_encode_signature_fixed(raw_sig: [Nat8]) : [Nat8] {
    if (raw_sig.size() != 64) {
        Debug.print("   ❌ Invalid raw signature length: " # Nat.toText(raw_sig.size()));
        return [];
    };

    let r : [Nat8] = Array.subArray(raw_sig, 0, 32);
    let s : [Nat8] = Array.subArray(raw_sig, 32, 32);

    // Remove leading zeros but ensure at least one byte
    func trim_leading_zeros(bytes: [Nat8]) : [Nat8] {
        var start = 0;
        while (start < bytes.size() - 1 and bytes[start] == 0) {
            start += 1;
        };
        Array.subArray<Nat8>(bytes, start, bytes.size() - start)
    };

    let r_trimmed : [Nat8] = trim_leading_zeros(r);
    let s_trimmed : [Nat8] = trim_leading_zeros(s);

    // Add leading zero if high bit is set (to keep positive in ASN.1)
    let r_final : [Nat8] = if (r_trimmed[0] >= 0x80) {
        Array.append<Nat8>([0x00], r_trimmed)
    } else {
        r_trimmed
    };
    
    let s_final : [Nat8] = if (s_trimmed[0] >= 0x80) {
        Array.append<Nat8>([0x00], s_trimmed)  
    } else {
        s_trimmed
    };

    // Check for low-S requirement (optional but recommended)
    // secp256k1 order n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
    // Half order for comparison
    let half_order : [Nat8] = hex_to_bytes("7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0");
    
    let s_to_use : [Nat8] = if (compare_big_endian(s_final, half_order) > 0) {
        // Convert to low-S by subtracting from order
        let order : [Nat8] = hex_to_bytes("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141");
        subtract_big_endian(order, s_final)
    } else {
        s_final
    };

    // Build DER structure: 0x30 [total_length] 0x02 [r_length] [r] 0x02 [s_length] [s]
    let r_len = Nat8.fromNat(r_final.size());
    let s_len = Nat8.fromNat(s_to_use.size());
    let total_len = Nat8.fromNat(r_final.size() + s_to_use.size() + 4); // +4 for the two 0x02 tags and lengths

    let der = Buffer.Buffer<Nat8>(6 + r_final.size() + s_to_use.size());
    der.add(0x30); // SEQUENCE tag
    der.add(total_len);
    der.add(0x02); // INTEGER tag for r
    der.add(r_len);
    der.append(Buffer.fromArray<Nat8>(r_final));
    der.add(0x02); // INTEGER tag for s
    der.add(s_len);
    der.append(Buffer.fromArray<Nat8>(s_to_use));

    Buffer.toArray(der)
};

// Helper function to compare big-endian byte arrays
private func compare_big_endian(a: [Nat8], b: [Nat8]) : Int {
    let len = Nat.min(a.size(), b.size());
    for (i in Iter.range(0, len - 1)) {
        if (a[i] < b[i]) return -1;
        if (a[i] > b[i]) return 1;
    };
    if (a.size() < b.size()) return -1;
    if (a.size() > b.size()) return 1;
    0
};

// Helper function to subtract big-endian byte arrays (a - b)
private func subtract_big_endian(a: [Nat8], b: [Nat8]) : [Nat8] {
    let result = Buffer.Buffer<Nat8>(a.size());
    var borrow = 0;
    
    for (i in Iter.range(0, a.size() - 1)) {
        let ai = Nat8.toNat(a[a.size() - 1 - i]);
        let bi = if (i < b.size()) { Nat8.toNat(b[b.size() - 1 - i]) } else { 0 };
        let diff = ai - bi - borrow;
        
        if (diff < 0) {
            result.add(Nat8.fromNat(diff + 256));
            borrow := 1;
        } else {
            result.add(Nat8.fromNat(diff));
            borrow := 0;
        };
    };
    
    let reversed = Buffer.toArray(result);
    Array.reverse<Nat8>(reversed)
};

// Updated transaction builder with proper DER signatures
public func build_transaction_p2pk_der_fixed(
    recipient: Text,
    amount: Nat64,
    fee: Nat64
) : async ?TransactionRequest {
    Debug.print("🏗️ Building P2PK transaction with proper DER signatures...");
    
    // Verify key match first
    let key_match = await verify_utxo_key_match();
    if (not key_match) {
        Debug.print("   ❌ Public key does not match UTXO");
        return null;
    };
    
    let utxos : [UTXO] = [{
        transactionId = "75b23c8a72ed66a1a9b0111a609b20314a9fe873785ab931cec1b3846e0eeafd";
        index = 1;
        amount = 400000000; // 4 KAS
        scriptPublicKey = "210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab";
        scriptVersion = 0;
        address = "kaspa:qypff6urmgk8452vjx55r63dhc38s6ewlavknmnefzgac42n3lt8cdchp86su6n";
    }];
    
    let total_in : Nat64 = utxos[0].amount;
    if (total_in < amount + fee) {
        Debug.print("   ❌ Insufficient funds");
        return null;
    };
    
    let change = total_in - amount - fee;
    
    // Decode recipient address and build transaction
    switch (Address.decode_address(recipient)) {
        case (? (addr_type, payload)) {
            let recipient_script_hex = if (addr_type == Address.SCHNORR) {
                "20" # hex_from_array(payload) # "ac"
            } else if (addr_type == Address.ECDSA) {
                "21" # hex_from_array(payload) # "ab"
            } else {
                Debug.print("   ❌ Unsupported address type");
                return null;
            };
            
            let tx : KaspaTransaction = {
                version = 0;
                inputs = [{
                    previousOutpoint = {
                        transactionId = utxos[0].transactionId;
                        index = utxos[0].index;
                    };
                    signatureScript = "";
                    sequence = 0xFFFFFFFFFFFFFFFF;
                    sigOpCount = 1;
                }];
                outputs = [
                    {
                        amount = amount;
                        scriptPublicKey = {
                            version = 0;
                            scriptPublicKey = recipient_script_hex;
                        };
                    },
                    {
                        amount = change;
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
            
            if (not validate_transaction(tx, utxos)) {
                return null;
            };
            
            switch (await sign_transaction_input_p2pk_der(tx, 0, utxos[0], "", false)) {
                case (null) null;
                case (?signature_script) {
                    ?{
                        transaction = {
                            version = tx.version;
                            inputs = [{
                                previousOutpoint = tx.inputs[0].previousOutpoint;
                                signatureScript = signature_script;
                                sequence = tx.inputs[0].sequence;
                                sigOpCount = tx.inputs[0].sigOpCount;
                            }];
                            outputs = tx.outputs;
                            lockTime = tx.lockTime;
                            subnetworkId = tx.subnetworkId;
                            gas = tx.gas;
                            payload = tx.payload;
                        };
                        allowOrphan = false;
                    }
                }
            }
        };
        case null null;
    };
};







};