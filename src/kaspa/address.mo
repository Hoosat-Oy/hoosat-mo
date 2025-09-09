// import Blob "mo:base/Blob";
// import Array "mo:base/Array";
// import Buffer "mo:base/Buffer";
// import Nat8 "mo:base/Nat8";
// import Nat32 "mo:base/Nat32";
// import Nat64 "mo:base/Nat64";
// import Text "mo:base/Text";
// import Char "mo:base/Char";
// import Iter "mo:base/Iter";

// module {
//   // Constants for address types
//   public let SCHNORR : Int = 0;
//   public let ECDSA : Int = 1;
//   public let P2SH : Int = 2;

//   // Constants for address lengths
//   public let SCHNORR_ADDRESS_LEN : Nat = 64;
//   public let ECDSA_ADDRESS_LEN : Nat = 65;

//   // Charset for CashAddr encoding
//   private let charset : [Char] = [
//     'q', 'p', 'z', 'r', 'y', '9', 'x', '8',
//     'g', 'f', '2', 't', 'v', 'd', 'w', '0',
//     's', '3', 'j', 'n', '5', '4', 'k', 'h',
//     'c', 'e', '6', 'm', 'u', 'a', '7', 'l'
//   ];

//   // Computes one step of the polymod algorithm
//   private func cashaddr_polymod_step(pre : Nat64) : Nat64 {
//     let b : Nat64 = pre >> 35;
//     let mask : Nat64 = 0x07ffffffff; // 35 bits
//     ((pre & mask) << 5) ^
//     (if ((b >> 0) & 1 == 1) 0x98f2bc8e61 else 0) ^
//     (if ((b >> 1) & 1 == 1) 0x79b76d99e2 else 0) ^
//     (if ((b >> 2) & 1 == 1) 0xf33e5fb3c4 else 0) ^
//     (if ((b >> 3) & 1 == 1) 0xae2eabe2a8 else 0) ^
//     (if ((b >> 4) & 1 == 1) 0x1e4f43e470 else 0)
//   };

//   // Computes the polymod checksum
//   private func PolyMod(prefix : [Nat8], payload : [Nat8]) : Nat64 {
//     var c : Nat64 = 1;
//     // Process prefix ("kaspa")
//     for (p in prefix.vals()) {
//       c := cashaddr_polymod_step(c) ^ Nat64.fromNat(Nat8.toNat(p & 0x1f));
//     };
//     // Separator (0)
//     c := cashaddr_polymod_step(c);
//     // Process payload
//     for (p in payload.vals()) {
//       c := cashaddr_polymod_step(c) ^ Nat64.fromNat(Nat8.toNat(p));
//     };
//     // 8 zero bytes for checksum
//     for (_ in Iter.range(0, 7)) {
//       c := cashaddr_polymod_step(c);
//     };
//     c ^ 1
//   };

//   // Creates an 8-byte checksum for the payload
//   private func create_checksum(payload : [Nat8]) : [Nat8] {
//     let prefix : [Nat8] = [107, 97, 115, 112, 97]; // ASCII "kaspa"
//     let mod : Nat64 = PolyMod(prefix, payload);
//     let checksum = Buffer.Buffer<Nat8>(8);
//     for (i in Iter.range(0, 7)) {
//       checksum.add(Nat8.fromNat(Nat64.toNat((mod >> Nat64.fromNat(5 * (7 - i))) & 0x1f)));
//     };
//     Buffer.toArray<Nat8>(checksum)
//   };

//   // Converts 8-bit bytes to 5-bit bytes
//   private func convert_bits(in_ : [Nat8], inbits : Nat, outbits : Nat, pad : Bool) : ?[Nat8] {
//     var val : Nat32 = 0;
//     var bits : Nat = 0;
//     let maxv : Nat32 = (Nat32.fromNat(1) << Nat32.fromNat(outbits)) - 1;
//     let out = Buffer.Buffer<Nat8>(in_.size() * inbits / outbits + 2);
//     for (byte in in_.vals()) {
//       val := (val << Nat32.fromNat(inbits)) | Nat32.fromNat(Nat8.toNat(byte));
//       bits += inbits;
//       while (bits >= outbits) {
//         bits -= outbits;
//         out.add(Nat8.fromNat(Nat32.toNat((val >> Nat32.fromNat(bits)) & maxv)));
//       };
//     };
//     if (pad) {
//       if (bits > 0) {
//         out.add(Nat8.fromNat(Nat32.toNat((val << Nat32.fromNat(outbits - bits)) & maxv)));
//       };
//     } else if (((val << Nat32.fromNat(outbits - bits)) & maxv) != 0 or bits >= inbits) {
//       return null;
//     };
//     ?Buffer.toArray<Nat8>(out)
//   };

//   // Encodes a hash into a CashAddr string (without the "kaspa:" prefix)
//   private func cashaddr_encode(hash : [Nat8], hash_length : Nat, version : Int) : ?Text {
//     let version_byte : Nat8 = switch (version) {
//       case (0) 0; // SCHNORR (P2PKH)
//       case (1) 1; // ECDSA
//       case (8) 8; // P2SH
//       case (_) return null;
//     };
//     let tmp = Buffer.Buffer<Nat8>(hash_length + 1);
//     tmp.add(version_byte);
//     tmp.append(Buffer.fromArray(hash));
//     let tmp_array = Buffer.toArray<Nat8>(tmp);
//     switch (convert_bits(tmp_array, 8, 5, true)) {
//       case (null) return null;
//       case (?payload) {
//         let checksum = create_checksum(payload);
//         let result = Buffer.Buffer<Char>(payload.size() + checksum.size());
//         for (p in payload.vals()) {
//           if (p >= 32) return null;
//           result.add(charset[Nat8.toNat(p)]);
//         };
//         for (c in checksum.vals()) {
//           if (c >= 32) return null;
//           result.add(charset[Nat8.toNat(c)]);
//         };
//         ?Text.fromIter(result.vals())
//       };
//     }
//   };

//   // Compresses a public key for Schnorr or ECDSA
//   public func compress_public_key(pubkey : Blob, addr_type : Int, len : Nat) : Blob {
//     let pubkey_array = Blob.toArray(pubkey);
//     if (pubkey_array.size() < 64) {
//       return Blob.fromArray([]);
//     };
//     if (addr_type == SCHNORR or addr_type == P2SH) {
//       if (len < 32) {
//         return Blob.fromArray([]);
//       };
//       return Blob.fromArray(Array.subArray(pubkey_array, 0, 32));
//     };
//     if (addr_type == ECDSA) {
//       if (len < 33) {
//         return Blob.fromArray([]);
//       };
//       let y_coord_last = pubkey_array[63];
//       let prefix : [Nat8] = if (y_coord_last % 2 == 0) [0x02] else [0x03];
//       return Blob.fromArray(Array.append(prefix, Array.subArray(pubkey_array, 0, 32)));
//     };
//     Blob.fromArray([])
//   };

//   // Generates a Kaspa address from a public key
//   public func address_from_pubkey(pubkey : Blob, addr_type : Int, len : Nat) : Text {
//     let address_len : Nat = if (addr_type == ECDSA) { ECDSA_ADDRESS_LEN } else { SCHNORR_ADDRESS_LEN };
//     let version : Int = if (addr_type == ECDSA) { 1 } else if (addr_type == P2SH) { 8 } else { 0 };
    
//     if (len < address_len or pubkey.size() < 64) {
//       return "";
//     };
    
//     let compressed_pub_size : Nat = if (addr_type == ECDSA) { 33 } else { 32 };
//     let compressed_public_key = compress_public_key(pubkey, addr_type, compressed_pub_size);
    
//     if (compressed_public_key.size() == 0) {
//       return "";
//     };
    
//     let hrp = "kaspa:";
//     switch (cashaddr_encode(Blob.toArray(compressed_public_key), compressed_public_key.size(), version)) {
//       case (null) "";
//       case (?encoded) hrp # encoded
//     }
//   };
// }








// import Blob "mo:base/Blob";
// import Array "mo:base/Array";
// import Buffer "mo:base/Buffer";
// import Nat8 "mo:base/Nat8";
// import Nat32 "mo:base/Nat32";
// import Nat64 "mo:base/Nat64";
// import Text "mo:base/Text";
// import Char "mo:base/Char";
// import Iter "mo:base/Iter";
// import Result "mo:base/Result";
// import ECDSA "mo:ecdsa"; // Main ECDSA module (may be used for other functions)
// import PublicKey "mo:ecdsa/PublicKey"; // Import PublicKey module
// import PrivateKey "mo:ecdsa/PrivateKey"; // Import PrivateKey module
// import Curve "mo:ecdsa/Curve"; // Import Curve module

// module {
//   // Constants for address types
//   public let SCHNORR : Int = 0;
//   public let ECDSA : Int = 1;
//   public let P2SH : Int = 2;

//   // Constants for address lengths
//   public let SCHNORR_ADDRESS_LEN : Nat = 64;
//   public let ECDSA_ADDRESS_LEN : Nat = 65;

//   // Charset for CashAddr encoding
//   private let charset : [Char] = [
//     'q', 'p', 'z', 'r', 'y', '9', 'x', '8',
//     'g', 'f', '2', 't', 'v', 'd', 'w', '0',
//     's', '3', 'j', 'n', '5', '4', 'k', 'h',
//     'c', 'e', '6', 'm', 'u', 'a', '7', 'l'
//   ];

//   // Computes one step of the polymod algorithm
//   private func cashaddr_polymod_step(pre : Nat64) : Nat64 {
//     let b : Nat64 = pre >> 35;
//     let mask : Nat64 = 0x07ffffffff; // 35 bits
//     ((pre & mask) << 5) ^
//     (if ((b >> 0) & 1 == 1) 0x98f2bc8e61 else 0) ^
//     (if ((b >> 1) & 1 == 1) 0x79b76d99e2 else 0) ^
//     (if ((b >> 2) & 1 == 1) 0xf33e5fb3c4 else 0) ^
//     (if ((b >> 3) & 1 == 1) 0xae2eabe2a8 else 0) ^
//     (if ((b >> 4) & 1 == 1) 0x1e4f43e470 else 0)
//   };

//   // Computes the polymod checksum
//   private func PolyMod(prefix : [Nat8], payload : [Nat8]) : Nat64 {
//     var c : Nat64 = 1;
//     for (p in prefix.vals()) {
//       c := cashaddr_polymod_step(c) ^ Nat64.fromNat(Nat8.toNat(p & 0x1f));
//     };
//     c := cashaddr_polymod_step(c);
//     for (p in payload.vals()) {
//       c := cashaddr_polymod_step(c) ^ Nat64.fromNat(Nat8.toNat(p));
//     };
//     for (_ in Iter.range(0, 7)) {
//       c := cashaddr_polymod_step(c);
//     };
//     c ^ 1
//   };

//   // Creates an 8-byte checksum for the payload
//   private func create_checksum(payload : [Nat8]) : [Nat8] {
//     let prefix : [Nat8] = [107, 97, 115, 112, 97]; // ASCII "kaspa"
//     let mod : Nat64 = PolyMod(prefix, payload);
//     let checksum = Buffer.Buffer<Nat8>(8);
//     for (i in Iter.range(0, 7)) {
//       checksum.add(Nat8.fromNat(Nat64.toNat((mod >> Nat64.fromNat(5 * (7 - i))) & 0x1f)));
//     };
//     Buffer.toArray<Nat8>(checksum)
//   };

//   // Converts 8-bit bytes to 5-bit bytes
//   private func convert_bits(in_ : [Nat8], inbits : Nat, outbits : Nat, pad : Bool) : ?[Nat8] {
//     var val : Nat32 = 0;
//     var bits : Nat = 0;
//     let maxv : Nat32 = (Nat32.fromNat(1) << Nat32.fromNat(outbits)) - 1;
//     let out = Buffer.Buffer<Nat8>(in_.size() * inbits / outbits + 2);
//     for (byte in in_.vals()) {
//       val := (val << Nat32.fromNat(inbits)) | Nat32.fromNat(Nat8.toNat(byte));
//       bits += inbits;
//       while (bits >= outbits) {
//         bits -= outbits;
//         out.add(Nat8.fromNat(Nat32.toNat((val >> Nat32.fromNat(bits)) & maxv)));
//       };
//     };
//     if (pad) {
//       if (bits > 0) {
//         out.add(Nat8.fromNat(Nat32.toNat((val << Nat32.fromNat(outbits - bits)) & maxv)));
//       };
//     } else if (((val << Nat32.fromNat(outbits - bits)) & maxv) != 0 or bits >= inbits) {
//       return null;
//     };
//     ?Buffer.toArray<Nat8>(out)
//   };

//   // Encodes a hash into a CashAddr string (without the "kaspa:" prefix)
//   private func cashaddr_encode(hash : [Nat8], hash_length : Nat, version : Int) : ?Text {
//     let version_byte : Nat8 = switch (version) {
//       case (0) 0; // SCHNORR (P2PKH)
//       case (1) 1; // ECDSA
//       case (8) 8; // P2SH
//       case (_) return null;
//     };
//     let tmp = Buffer.Buffer<Nat8>(hash_length + 1);
//     tmp.add(version_byte);
//     tmp.append(Buffer.fromArray(hash));
//     let tmp_array = Buffer.toArray<Nat8>(tmp);
//     switch (convert_bits(tmp_array, 8, 5, true)) {
//       case (null) return null;
//       case (?payload) {
//         let checksum = create_checksum(payload);
//         let result = Buffer.Buffer<Char>(payload.size() + checksum.size());
//         for (p in payload.vals()) {
//           if (p >= 32) return null;
//           result.add(charset[Nat8.toNat(p)]);
//         };
//         for (c in checksum.vals()) {
//           if (c >= 32) return null;
//           result.add(charset[Nat8.toNat(c)]);
//         };
//         ?Text.fromIter(result.vals())
//       };
//     }
//   };

//   // Compresses a public key for Schnorr or P2SH (ECDSA handled via library)
//   public func compress_public_key(pubkey : Blob, addr_type : Int, len : Nat) : Blob {
//     let pubkey_array = Blob.toArray(pubkey);
//     if (pubkey_array.size() < 64) {
//       return Blob.fromArray([]);
//     };
//     if (addr_type == SCHNORR or addr_type == P2SH) {
//       if (len < 32) {
//         return Blob.fromArray([]);
//       };
//       return Blob.fromArray(Array.subArray(pubkey_array, 0, 32));
//     };
//     // For ECDSA, we rely on the library's compressed format
//     Blob.fromArray([])
//   };

//   // Compresses a public key from the ECDSA library's PublicKey object
//   public func compress_public_key_from_ecdsa(pubkey : PublicKey.PublicKey, addr_type : Int) : Blob {
//     if (addr_type == ECDSA) {
//       // Use the library's compressed format (0x02 or 0x03 || X, 33 bytes)
//       return Blob.fromArray(pubkey.toBytes(#compressed));
//     };
//     // For Schnorr or P2SH, use the X coordinate (32 bytes)
//     let uncompressed = pubkey.toBytes(#uncompressed); // 0x04 || X || Y
//     if (uncompressed.size() < 65) {
//       return Blob.fromArray([]);
//     };
//     Blob.fromArray(Array.subArray(uncompressed, 1, 32)) // Extract X coordinate
//   };

//   // Generates a Kaspa address from a public key (supports both Blob and ECDSA PublicKey)
//   public func address_from_pubkey(pubkey : { #blob : Blob; #ecdsa : PublicKey.PublicKey }, addr_type : Int, len : Nat) : Text {
//     let address_len : Nat = if (addr_type == ECDSA) { ECDSA_ADDRESS_LEN } else { SCHNORR_ADDRESS_LEN };
//     let version : Int = if (addr_type == ECDSA) { 1 } else if (addr_type == P2SH) { 8 } else { 0 };
    
//     let compressed_pub_size : Nat = if (addr_type == ECDSA) { 33 } else { 32 };
//     let compressed_public_key = switch (pubkey) {
//       case (#blob(b)) {
//         if (len < address_len or b.size() < 64) {
//           return "";
//         };
//         compress_public_key(b, addr_type, compressed_pub_size)
//       };
//       case (#ecdsa(p)) {
//         compress_public_key_from_ecdsa(p, addr_type)
//       };
//     };
    
//     if (compressed_public_key.size() == 0) {
//       return "";
//     };
    
//     let hrp = "kaspa:";
//     switch (cashaddr_encode(Blob.toArray(compressed_public_key), compressed_public_key.size(), version)) {
//       case (null) "";
//       case (?encoded) hrp # encoded
//     }
//   };

//   // Generates an ECDSA key pair using the ECDSA library (default to secp256k1 for Kaspa)
//   public func generateECDSAKeyPair(entropy : ?[Nat8]) : Result.Result<(PrivateKey.PrivateKey, PublicKey.PublicKey), Text> {
//     let curve = Curve.secp256k1(); // Kaspa typically uses secp256k1
//     let entropy_iter = switch (entropy) {
//       case (?bytes) bytes.vals();
//       case (null) {
//         // Generate random entropy (e.g., 32 bytes for 256-bit curve)
//         let random_bytes = Array.tabulate<Nat8>(32, func(_) { Nat8.fromNat(0) }); // Placeholder; replace with actual random source
//         random_bytes.vals()
//       };
//     };
//     switch (PrivateKey.generate(entropy_iter, curve)) {
//       case (#ok(priv)) {
//         let pub = priv.getPublicKey();
//         #ok((priv, pub))
//       };
//       case (#err(e)) #err("Failed to generate ECDSA key pair: " # e)
//     }
//   };

//   // Generates a Kaspa ECDSA address and returns private key and address
//   public func generateECDSAAddress(entropy : ?[Nat8]) : Result.Result<(Blob, Text), Text> {
//     switch (generateECDSAKeyPair(entropy)) {
//       case (#ok((priv, pub))) {
//         let addr = address_from_pubkey(#ecdsa(pub), ECDSA, ECDSA_ADDRESS_LEN);
//         if (addr == "") {
//           #err("Failed to generate valid ECDSA address")
//         } else {
//           #ok((Blob.fromArray(priv.toBytes(#raw)), addr))
//         }
//       };
//       case (#err(e)) #err(e)
//     }
//   };
// }












import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import Char "mo:base/Char";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Bool "mo:base/Bool";

module {
  public let SCHNORR : Nat = 0;
  public let ECDSA : Nat = 1;
  public let P2SH : Nat = 2;

  public let SCHNORR_PAYLOAD_LEN : Nat = 32;
  public let ECDSA_PAYLOAD_LEN : Nat = 33;

  private let charset : [Char] = [
    'q', 'p', 'z', 'r', 'y', '9', 'x', '8',
    'g', 'f', '2', 't', 'v', 'd', 'w', '0',
    's', '3', 'j', 'n', '5', '4', 'k', 'h',
    'c', 'e', '6', 'm', 'u', 'a', '7', 'l'
  ];

  private func cashaddr_polymod_step(pre : Nat64) : Nat64 {
    let b : Nat64 = pre >> 35;
    let mask : Nat64 = 0x07ffffffff;
    ((pre & mask) << 5) ^
    (if ((b >> 0) & 1 == 1) 0x98f2bc8e61 else 0) ^
    (if ((b >> 1) & 1 == 1) 0x79b76d99e2 else 0) ^
    (if ((b >> 2) & 1 == 1) 0xf33e5fb3c4 else 0) ^
    (if ((b >> 3) & 1 == 1) 0xae2eabe2a8 else 0) ^
    (if ((b >> 4) & 1 == 1) 0x1e4f43e470 else 0)
  };

  private func PolyMod(prefix : [Nat8], payload : [Nat8]) : Nat64 {
    var c : Nat64 = 1;
    for (p in prefix.vals()) {
      c := cashaddr_polymod_step(c) ^ Nat64.fromNat(Nat8.toNat(p & 0x1f));
    };
    c := cashaddr_polymod_step(c);
    for (p in payload.vals()) {
      c := cashaddr_polymod_step(c) ^ Nat64.fromNat(Nat8.toNat(p));
    };
    for (_ in Iter.range(0, 7)) {
      c := cashaddr_polymod_step(c);
    };
    c ^ 1
  };

  private func create_checksum(payload : [Nat8]) : [Nat8] {
    let prefix : [Nat8] = [107, 97, 115, 112, 97]; // "kaspa"
    let mod : Nat64 = PolyMod(prefix, payload);
    let checksum = Buffer.Buffer<Nat8>(8);
    for (i in Iter.range(0, 7)) {
      let value = Nat8.fromNat(Nat64.toNat((mod >> Nat64.fromNat(5 * (7 - i))) & 0x1f));
      // Debug.print("Checksum value " # Nat.toText(i) # ": " # Nat8.toText(value));
      checksum.add(value);
    };
    Buffer.toArray<Nat8>(checksum)
  };

  private func convert_bits(in_ : [Nat8], inbits : Nat, outbits : Nat, pad : Bool) : ?[Nat8] {
    var val : Nat32 = 0;
    var bits : Nat = 0;
    let maxv : Nat32 = (Nat32.fromNat(1) << Nat32.fromNat(outbits)) - 1;
    let out = Buffer.Buffer<Nat8>(in_.size() * inbits / outbits + 2);
    // Debug.print("convert_bits input length: " # Nat.toText(in_.size()));
    for (byte in in_.vals()) {
      val := (val << Nat32.fromNat(inbits)) | Nat32.fromNat(Nat8.toNat(byte));
      bits += inbits;
      while (bits >= outbits) {
        bits -= outbits;
        let value = Nat8.fromNat(Nat32.toNat((val >> Nat32.fromNat(bits)) & maxv));
        if (value >= 32) {
          Debug.print("convert_bits invalid value: " # Nat8.toText(value));
          return null;
        };
        out.add(value);
        // Debug.print("convert_bits output value: " # Nat8.toText(value));
      };
    };
    if (pad) {
      if (bits > 0) {
        let value = Nat8.fromNat(Nat32.toNat((val << Nat32.fromNat(outbits - bits)) & maxv));
        if (value >= 32) {
          Debug.print("convert_bits invalid padding value: " # Nat8.toText(value));
          return null;
        };
        out.add(value);
        Debug.print("convert_bits padding value: " # Nat8.toText(value));
      };
    } else if (((val << Nat32.fromNat(outbits - bits)) & maxv) != 0 or bits >= inbits) {
      Debug.print("convert_bits failed: non-zero leftover or too many bits");
      return null;
    };
    ?Buffer.toArray<Nat8>(out)
  };

  private func cashaddr_encode(payload_bytes : [Nat8], version : Nat) : ?Text {
    // Debug.print("cashaddr_encode: version = " # Nat.toText(version) # ", payload length = " # Nat.toText(payload_bytes.size()));
    let version_byte : Nat8 = switch (version) {
      case (0) 0; // SCHNORR
      case (1) 1; // ECDSA
      case (2) 8; // P2SH
      case (_) {
        Debug.print("Invalid version: " # Nat.toText(version));
        return null;
      };
    };
    let data = Buffer.Buffer<Nat8>(payload_bytes.size() + 1);
    data.add(version_byte);
    data.append(Buffer.fromArray(payload_bytes));
    let data_array = Buffer.toArray<Nat8>(data);
    // Debug.print("Data array length: " # Nat.toText(data_array.size()));
    switch (convert_bits(data_array, 8, 5, true)) {
      case (null) {
        Debug.print("convert_bits returned null");
        return null;
      };
      case (?converted) {
        Debug.print("Converted length: " # Nat.toText(converted.size()));
        let checksum = create_checksum(converted);
        Debug.print("Checksum length: " # Nat.toText(checksum.size()));
        let combined = Array.append(converted, checksum);
        let result = Buffer.Buffer<Char>(combined.size());
        for (p in combined.vals()) {
          if (p >= 32) {
            Debug.print("Invalid charset value: " # Nat8.toText(p));
            return null;
          };
          result.add(charset[Nat8.toNat(p)]);
        };
        ?Text.fromIter(result.vals())
      };
    }
  };

  public func address_from_pubkey(pubkey : Blob, addr_type : Nat) : Text {
    let pubkey_bytes = Blob.toArray(pubkey);
    // Debug.print("address_from_pubkey: addr_type = " # Nat.toText(addr_type) # ", pubkey length = " # Nat.toText(pubkey_bytes.size()));
    // Debug.print("Constants: SCHNORR = " # Nat.toText(SCHNORR) # ", ECDSA = " # Nat.toText(ECDSA) # ", P2SH = " # Nat.toText(P2SH));
    // Debug.print("Payload lengths: SCHNORR = " # Nat.toText(SCHNORR_PAYLOAD_LEN) # ", ECDSA = " # Nat.toText(ECDSA_PAYLOAD_LEN));
    
    let expected_len = if (addr_type == ECDSA) {
      ECDSA_PAYLOAD_LEN
    } else if (addr_type == SCHNORR or addr_type == P2SH) {
      SCHNORR_PAYLOAD_LEN
    } else {
      Debug.print("Unknown addr_type: " # Nat.toText(addr_type));
      return "";
    };
    // Debug.print("Checking: pubkey size = " # Nat.toText(pubkey_bytes.size()) # ", expected = " # Nat.toText(expected_len));
    let is_valid_len = pubkey_bytes.size() == expected_len;
    // Debug.print("is_valid_len: " # Bool.toText(is_valid_len));
    
    if (not is_valid_len) {
      Debug.print("Invalid public key length");
      return "";
    };
    
    let hrp = "kaspa:";
    switch (cashaddr_encode(pubkey_bytes, addr_type)) {
      case (null) {
        Debug.print("cashaddr_encode returned null");
        return "";
      };
      case (?encoded) hrp # encoded
    }
  };
}
