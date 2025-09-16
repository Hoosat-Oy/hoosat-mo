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

  // private func convert_bits(in_ : [Nat8], inbits : Nat, outbits : Nat, pad : Bool) : ?[Nat8] {
  //   var val : Nat32 = 0;
  //   var bits : Nat = 0;
  //   let maxv : Nat32 = (Nat32.fromNat(1) << Nat32.fromNat(outbits)) - 1;
  //   let out = Buffer.Buffer<Nat8>(in_.size() * inbits / outbits + 2);
  //   // Debug.print("convert_bits input length: " # Nat.toText(in_.size()));
  //   for (byte in in_.vals()) {
  //     val := (val << Nat32.fromNat(inbits)) | Nat32.fromNat(Nat8.toNat(byte));
  //     bits += inbits;
  //     while (bits >= outbits) {
  //       bits -= outbits;
  //       let value = Nat8.fromNat(Nat32.toNat((val >> Nat32.fromNat(bits)) & maxv));
  //       if (value >= 32) {
  //         Debug.print("convert_bits invalid value: " # Nat8.toText(value));
  //         return null;
  //       };
  //       out.add(value);
  //       // Debug.print("convert_bits output value: " # Nat8.toText(value));
  //     };
  //   };
  //   if (pad) {
  //     if (bits > 0) {
  //       let value = Nat8.fromNat(Nat32.toNat((val << Nat32.fromNat(outbits - bits)) & maxv));
  //       if (value >= 32) {
  //         Debug.print("convert_bits invalid padding value: " # Nat8.toText(value));
  //         return null;
  //       };
  //       out.add(value);
  //       Debug.print("convert_bits padding value: " # Nat8.toText(value));
  //     };
  //   } else if (((val << Nat32.fromNat(outbits - bits)) & maxv) != 0 or bits >= inbits) {
  //     Debug.print("convert_bits failed: non-zero leftover or too many bits");
  //     return null;
  //   };
  //   ?Buffer.toArray<Nat8>(out)
  // };

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
      // Only validate >=32 for outbits=5 (encoding to Bech32 charset); skip for decoding (outbits=8)
      if (outbits == 5 and Nat8.toNat(value) >= 32) {
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
      // Only validate >=32 for outbits=5 (encoding to Bech32 charset); skip for decoding (outbits=8)
      if (outbits == 5 and Nat8.toNat(value) >= 32) {
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



  // Convert byte array to hex string
  public func hex_from_array(bytes: [Nat8]) : Text {
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

    // Helper to convert hex to bytes
    public func array_from_hex(hex: Text) : [Nat8] {
        let chars = Text.toIter(hex);
        let result = Buffer.Buffer<Nat8>(hex.size() / 2);
        var byte: Nat = 0;
        var is_high = true;
        for (c in chars) {
            let val = if (c >= '0' and c <= '9') {
                Nat32.toNat(Char.toNat32(c) - Char.toNat32('0'))
            } else if (c >= 'a' and c <= 'f') {
                Nat32.toNat(Char.toNat32(c) - Char.toNat32('a') + 10)
            } else if (c >= 'A' and c <= 'F') {
                Nat32.toNat(Char.toNat32(c) - Char.toNat32('A') + 10)
            } else {
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

  // Convert public key or address payload to scriptPublicKey
  // public func pubkey_to_script(pubkey : [Nat8], addr_type : Nat) : Text {
  //   if (addr_type == SCHNORR and pubkey.size() == SCHNORR_PAYLOAD_LEN) {
  //     // P2PK (Schnorr): OP_DATA_32 <32-byte pubkey> OP_CHECKSIG
  //     let script = Buffer.Buffer<Nat8>(34);
  //     script.add(32); // OP_DATA_32
  //     script.append(Buffer.fromArray(pubkey));
  //     script.add(0xAC); // OP_CHECKSIG
  //     hex_from_array(Buffer.toArray(script))
  //   } else if (addr_type == ECDSA and pubkey.size() == ECDSA_PAYLOAD_LEN) {
  //     // P2PKH (ECDSA): OP_DUP OP_HASH256 <20-byte hash> OP_EQUALVERIFY OP_CHECKSIG
  //     // Note: Kaspa ECDSA typically uses compressed pubkeys, but P2PKH uses HASH256(pubkey)
  //     let hash = Array.subArray(pubkey, 0, 20); // Assume pubkey is already hashed for simplicity
  //     let script = Buffer.Buffer<Nat8>(25);
  //     script.add(0x76); // OP_DUP
  //     script.add(0xA9); // OP_HASH256
  //     script.add(20);   // OP_DATA_20
  //     script.append(Buffer.fromArray(hash));
  //     script.add(0x88); // OP_EQUALVERIFY
  //     script.add(0xAC); // OP_CHECKSIG
  //     hex_from_array(Buffer.toArray(script))
  //   } else {
  //     Debug.print("Invalid addr_type or pubkey length: addr_type=" # Nat.toText(addr_type) # ", length=" # Nat.toText(pubkey.size()));
  //     ""
  //   }
  // };
  // Convert public key or address payload to scriptPublicKey
  public func pubkey_to_script(pubkey : [Nat8], addr_type : Nat) : Text {
    if (addr_type == SCHNORR and pubkey.size() == SCHNORR_PAYLOAD_LEN) {
      // P2PK (Schnorr): OP_DATA_32 <32-byte pubkey> OP_CHECKSIG
      let script = Buffer.Buffer<Nat8>(34);
      script.add(32); // OP_DATA_32
      script.append(Buffer.fromArray(pubkey));
      script.add(0xAC); // OP_CHECKSIG
      hex_from_array(Buffer.toArray(script))
    } else if (addr_type == ECDSA and pubkey.size() == ECDSA_PAYLOAD_LEN) {
      // P2PK (ECDSA): OP_DATA_33 <33-byte pubkey> OP_CHECKSIG
      let script = Buffer.Buffer<Nat8>(35);
      script.add(33); // OP_DATA_33
      script.append(Buffer.fromArray(pubkey));
      script.add(0xAB); // OP_CHECKSIG (ECDSA)
      hex_from_array(Buffer.toArray(script))
    } else {
      Debug.print("Invalid addr_type or pubkey length: addr_type=" # Nat.toText(addr_type) # ", length=" # Nat.toText(pubkey.size()));
      ""
    }
  };

  public func decode_address(address: Text) : ?(Nat, [Nat8]) {
    if (not Text.startsWith(address, #text("kaspa:"))) {
      Debug.print("Invalid Kaspa address prefix");
      return null;
    };
    switch (Text.stripStart(address, #text("kaspa:"))) {
      case (null) {
        Debug.print("Failed to strip 'kaspa:' prefix");
        return null;
      };
      case (?addr) {
        let chars = Text.toIter(addr);
        let data = Buffer.Buffer<Nat8>(addr.size());
        for (c in chars) {
          let idx = Array.indexOf<Char>(c, charset, func(a, b) { a == b });
          switch (idx) {
            case (null) {
              Debug.print("Invalid character in address: " # Text.fromChar(c));
              return null;
            };
            case (?i) {
              if (i >= 32) {
                Debug.print("Invalid charset index: " # Nat.toText(i));
                return null;
              };
              data.add(Nat8.fromNat(i));
            };
          };
        };
        let data_array = Buffer.toArray<Nat8>(data);
        if (data_array.size() < 8) {
          Debug.print("Address too short for checksum");
          return null;
        };
        // Verify checksum
        let payload = Array.subArray(data_array, 0, data_array.size() - 8);
        let checksum = Array.subArray(data_array, data_array.size() - 8, 8);
        let computed_checksum = create_checksum(payload);
        if (not Array.equal(checksum, computed_checksum, func(a, b) { a == b })) {
          Debug.print("Checksum verification failed");
          return null;
        };
        // Convert 5-bit to 8-bit
        switch (convert_bits(payload, 5, 8, false)) {
          case (null) {
            Debug.print("Failed to convert 5-bit to 8-bit");
            return null;
          };
          case (?converted) {
            if (converted.size() < 1) {
              Debug.print("No version byte in payload");
              return null;
            };
            let version_byte = converted[0];
            let payload_bytes = Array.subArray(converted, 1, converted.size() - 1);
            let addr_type = switch (version_byte) {
              case (0) SCHNORR;
              case (1) ECDSA;
              case (8) P2SH;
              case (_) {
                Debug.print("Unknown version byte: " # Nat8.toText(version_byte));
                return null;
              };
            };
            let expected_len = if (addr_type == ECDSA) { ECDSA_PAYLOAD_LEN } else { SCHNORR_PAYLOAD_LEN };
            if (payload_bytes.size() != expected_len) {
              Debug.print("Invalid payload length: " # Nat.toText(payload_bytes.size()) # ", expected: " # Nat.toText(expected_len));
              return null;
            };
            ?(addr_type, payload_bytes)
          };
        };
      };
    };
  };
}
