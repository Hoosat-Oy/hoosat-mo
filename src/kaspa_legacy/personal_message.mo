import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Nat8 "mo:base/Nat8";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Cycles "mo:base/ExperimentalCycles";
import Blake2b "mo:blake2b";

module {
  // Constant for message signing key
  private let MESSAGE_SIGNING_KEY : [Nat8] = [
    80, 101, 114, 115, 111, 110, 97, 108, 77, 101, 115, 115, 97, 103, 101, 83, 105, 103, 110, 105, 110, 103, 72, 97, 115, 104
  ]; // "PersonalMessageSigningHash"
  

  public func hash_personal_message(
    message_bytes : [Nat8],
    message_len : Nat,
    out_hash : [var Nat8]
) : Bool {
    if (out_hash.size() < 32) {
        return false;
    };

    let config = {
        digest_length = 32; // 256-bit output
        key = ?Blob.fromArray(MESSAGE_SIGNING_KEY);
        salt = null;
        personal = null;
    };

    let state = Blake2b.init(config);

    // Feed message
    Blake2b.update(state, Blob.fromArray(message_bytes));

    let hash_result = Blake2b.finalize(state);
    let hashArr = Blob.toArray(hash_result);

    if (hashArr.size() != 32) {
        return false;
    };

    // Copy into provided buffer
    for (i in Iter.range(0, 31)) {
        out_hash[i] := hashArr[i];
    };

    true
};

//   public func ecdsa_sign(message_hash : Blob, private_key : Blob) : ?Blob {
//     // In production, use:
//     // let management_canister = actor("aaaaa-aa") : actor {
//     //   sign_with_ecdsa : { message_hash : Blob; derivation_path : [Blob]; key_id : { curve : { #secp256k1 }; name : Text } } -> async { signature : Blob };
//     // };
//     // Cycles.add<system>(10_000_000_000);
//     // let result = await management_canister.sign_with_ecdsa({
//     //   message_hash = message_hash;
//     //   derivation_path = [];
//     //   key_id = { curve = #secp256k1; name = "dfx_test_key" };
//     // });
//     // ?result.signature
    

//     // Mock ECDSA signing (replace with ICP management_canister.sign_with_ecdsa in production)
//     ?Blob.fromArray([
//       0x40, 0xB9, 0xBB, 0x2B, 0xE0, 0xAE, 0x02, 0x60, 0x72, 0x79, 0xED, 0xA6, 0x40, 0x15, 0xA8, 0xD8,
//       0x6E, 0x37, 0x63, 0x27, 0x91, 0x70, 0x34, 0x0B, 0x82, 0x43, 0xF7, 0xCE, 0x53, 0x44, 0xD7, 0x7A,
//       0xFF, 0x11, 0x91, 0x59, 0x8B, 0xAF, 0x2F, 0xD2, 0x61, 0x49, 0xCA, 0xC3, 0xB4, 0xB1, 0x2C, 0x2C,
//       0x43, 0x32, 0x61, 0xC0, 0x08, 0x34, 0xDB, 0x60, 0x98, 0xCB, 0x17, 0x2A, 0xA4, 0x8E, 0xF5, 0x22
//     ]) // Mock signature from Ledger's commented test
//   };


// Async ECDSA signing using ICP management canister
  public func ecdsa_sign(message_hash : Blob, derivation_path : [Blob], key_name : Text) : async ?Blob {
    let management_canister = actor("aaaaa-aa") : actor {
      sign_with_ecdsa : { message_hash : Blob; derivation_path : [Blob]; key_id : { curve : { #secp256k1 }; name : Text } } -> async { signature : Blob };
    };
    try {
      Cycles.add(30_000_000_000); // Match sample code
      let result = await management_canister.sign_with_ecdsa({
        message_hash = message_hash;
        derivation_path = derivation_path;
        key_id = { curve = #secp256k1; name = key_name };
      });
      ?result.signature
    } catch (err) {
      null
    }
  };

  // Mock ECDSA verification (replace with secp256k1 library in production)
  public func ecdsa_verify(message_hash : Blob, signature : Blob, public_key : Blob) : Bool {
    // Placeholder: Use a secp256k1 library or ICP verify for production
    true // Temporary for testing
  };

  // Public function to sign a personal message (aligned with sign_message)
  // Public function to sign a personal message
  public func sign_personal_message(message : Text, derivation_path : [Blob], key_name : Text) : async ?Blob {
    let message_bytes : [Nat8] = Blob.toArray(Text.encodeUtf8(message));
    let out_hash = Array.init<Nat8>(32, 0);
    let hash_result = hash_personal_message(message_bytes, message_bytes.size(), out_hash);
    if (not hash_result) {
      return null;
    };
    let message_hash = Blob.fromArray(Array.freeze(out_hash));
    await ecdsa_sign(message_hash, derivation_path, key_name)
  };
}