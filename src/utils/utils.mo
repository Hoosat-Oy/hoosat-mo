import Char "mo:base/Char";
import Buffer "mo:base/Buffer";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";

module {

  // Convert byte array to hex string
  public func hex_from_array(bytes : [Nat8]) : Text {
    let hex_chars : [Char] = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'];
    let result = Buffer.Buffer<Char>(bytes.size() * 2);
    for (b in bytes.vals()) {
      let high = Nat8.toNat(b / 16);
      let low = Nat8.toNat(b % 16);
      result.add(hex_chars[high]);
      result.add(hex_chars[low]);
    };
    Text.fromIter(result.vals());
  };

  // Helper to convert hex to bytes
  public func array_from_hex(hex : Text) : [Nat8] {
    let chars = Text.toIter(hex);
    let result = Buffer.Buffer<Nat8>(hex.size() / 2);
    var byte : Nat = 0;
    var is_high = true;
    for (c in chars) {
      let val = if (c >= '0' and c <= '9') {
        Nat32.toNat(Char.toNat32(c) - Char.toNat32('0'));
      } else if (c >= 'a' and c <= 'f') {
        Nat32.toNat(Char.toNat32(c) - Char.toNat32('a') + 10);
      } else if (c >= 'A' and c <= 'F') {
        Nat32.toNat(Char.toNat32(c) - Char.toNat32('A') + 10);
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
      };
    };
    Buffer.toArray(result);
  };

  // Helper: Convert hex character to Nat8
  public func hexCharToNat8(c: Char): Nat8 {
    let n: Nat32 = Char.toNat32(c);
    if (n >= Char.toNat32('0') and n <= Char.toNat32('9')) {
      Nat8.fromNat(Nat32.toNat(n - Char.toNat32('0')))
    } else if (n >= Char.toNat32('a') and n <= Char.toNat32('f')) {
      Nat8.fromNat(10 + Nat32.toNat(n - Char.toNat32('a')))
    } else if (n >= Char.toNat32('A') and n <= Char.toNat32('F')) {
      Nat8.fromNat(10 + Nat32.toNat(n - Char.toNat32('A')))
    } else {
      assert false; // Invalid hex digit
      0
    };
  };
  
};
