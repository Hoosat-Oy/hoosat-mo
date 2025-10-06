import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Nat8 "mo:base/Nat8";
import Debug "mo:base/Debug";

import { test } "mo:test/async";

import Address "../src/address";
import PersonalMessage "../src/personal_message";

persistent actor {
  public func runTests() : async () {
    Debug.print("Running personal message and address tests");

    await test("hash personal message", func() : async () {
      let message = "Hello Hoosat!";
      let message_blob : Blob = Text.encodeUtf8(message);
      let message_bytes : [Nat8] = Blob.toArray(message_blob);
      let out_hash = Array.init<Nat8>(32, 0);

      let ok = PersonalMessage.hash_personal_message(message_bytes, message_bytes.size(), out_hash);
      assert ok;

      let expected_hash : [Nat8] = [
        172, 68, 72, 77, 113, 198, 104, 48,
        127, 68, 7, 235, 240, 167, 17, 51,
        30, 120, 19, 220, 22, 193, 189, 12,
        99, 189, 65, 38, 52, 115, 65, 182
      ];
      assert Array.freeze(out_hash) == expected_hash;
    });

    await test("ECDSA address", func() : async () {
      let compressed_public_key = Blob.fromArray([
        0x02,
        0xD5, 0xFD, 0xC7, 0xAD, 0x11, 0xA6, 0x5D, 0x0B, 0xBE, 0x78, 0x82, 0xFC,
        0x3D, 0xBC, 0x91, 0xB5, 0x86, 0x1D, 0x18, 0x2D, 0xCC, 0xE7, 0x9F, 0x7C,
        0x1B, 0xE5, 0xBF, 0xD3, 0x0A, 0x67, 0x7C, 0xD6
      ]);

      let expected_address = "Hoosat:qypdtlw845g6vhgtheug9lpahjgmtpsarqkueeul0sd7t07npfnhe4s73hcw7fv";
      let address = Address.address_from_pubkey(compressed_public_key, Address.ECDSA);

      assert address != "";
      assert address == expected_address;
    });

    await test("Schnorr address", func() : async () {
      let schnorr_key = Blob.fromArray([
        0xD5, 0xFD, 0xC7, 0xAD, 0x11, 0xA6, 0x5D, 0x0B, 0xBE, 0x78, 0x82, 0xFC,
        0x3D, 0xBC, 0x91, 0xB5, 0x86, 0x1D, 0x18, 0x2D, 0xCC, 0xE7, 0x9F, 0x7C,
        0x1B, 0xE5, 0xBF, 0xD3, 0x0A, 0x67, 0x7C, 0xD6
      ]);

      let schnorr_address = Address.address_from_pubkey(schnorr_key, Address.SCHNORR);
      assert schnorr_address != "";
    });

    await test("P2SH address", func() : async () {
      let p2sh_hash = Blob.fromArray(Array.freeze(Array.init<Nat8>(32, 0)));
      let p2sh_address = Address.address_from_pubkey(p2sh_hash, Address.P2SH);
      assert p2sh_address != "";
    });

    await test("Japanese message", func() : async () {
      let kanji_message = "こんにちは世界";
      let kanji_message_blob = Text.encodeUtf8(kanji_message);
      let kanji_message_bytes = Blob.toArray(kanji_message_blob);
      let kanji_out_hash = Array.init<Nat8>(32, 0);

      let ok = PersonalMessage.hash_personal_message(kanji_message_bytes, kanji_message_bytes.size(), kanji_out_hash);
      assert ok;
    });

    await test("Long message", func() : async () {
      let long_message = "Lorem ipsum dolor sit amet ... cupiditate id eius";
      let long_message_blob = Text.encodeUtf8(long_message);
      let long_message_bytes = Blob.toArray(long_message_blob);
      let long_out_hash = Array.init<Nat8>(32, 0);

      let ok = PersonalMessage.hash_personal_message(long_message_bytes, long_message_bytes.size(), long_out_hash);
      assert ok;
    });
  };
};
