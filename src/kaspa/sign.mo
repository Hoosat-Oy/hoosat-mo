  import Types "./types";
  import Sighash "./sighash";
  import Array "mo:base/Array";
  import Blob "mo:base/Blob";
  import Principal "mo:base/Principal";
  import Result "mo:base/Result";
  import Cycles "mo:base/ExperimentalCycles";
  import Nat8 "mo:base/Nat8";
  import Text "mo:base/Text";
  import Debug "mo:base/Debug";
  
module {

  // Helper: Convert byte array to hex string (from sighash.test.mo)
  func hex_from_array(bytes: [Nat8]): Text {
    let hexChars = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'];
    var result = "";
    for (byte in bytes.vals()) {
      let high = Nat8.toNat(byte / 16);
      let low = Nat8.toNat(byte % 16);
      result := result # Text.fromChar(hexChars[high]) # Text.fromChar(hexChars[low]);
    };
    result
  };

  public type KeyPair = {
    publicKey: [Nat8];
    privateKey: ?[Nat8]; // Optional, as ICP ECDSA API doesn't expose private key
  };

  // Generate ECDSA keypair using ICP API
  public func generate_keypair(key_name: Text): async Result.Result<KeyPair, Text> {
    let key_id = { name = key_name; curve = #secp256k1; derivation_path = [] : [Blob] };
    switch (await ic0.ecdsa_public_key(key_id, Principal.toBlob(Principal.fromActor(self)))) {
      case (#ok(pubkey)) {
        #ok({ publicKey = Blob.toArray(pubkey); privateKey = null })
      };
      case (#err(err)) {
        #err("Failed to generate public key: " # debug_show(err))
      };
    }
  };

  // Sign ECDSA sighash using ICP API
  public func sign_ecdsa_sighash(sighash: [Nat8], key_name: Text): async Result.Result<[Nat8], Text> {
    let key_id = { name = key_name; curve = #secp256k1; derivation_path = [] : [Blob] };
    switch (await ic0.sign_with_ecdsa(key_id, Blob.fromArray(sighash))) {
      case (#ok(signature)) {
        #ok(Blob.toArray(signature))
      };
      case (#err(err)) {
        #err("Signing failed: " # debug_show(err))
      };
    }
  };

  // Create signatureScript for P2PKH
  public func create_signature_script(signature: [Nat8], public_key: [Nat8]): [Nat8] {
    // Format: <length of signature> <signature> <length of public key> <public_key>
    let sig_len = Array.init<Nat8>(1, Nat8.fromNat(signature.size()));
    let pubkey_len = Array.init<Nat8>(1, Nat8.fromNat(public_key.size()));
    Array.append(Array.append(sig_len, signature), Array.append(pubkey_len, public_key))
  };

  // Sign transaction input for P2PKH
  public func sign_transaction_input_p2pk_raw(
    tx: Types.KaspaTransaction,
    input_index: Nat,
    utxo: Types.UTXO,
    hash_type: Sighash.SigHashType,
    reused_values: Sighash.SighashReusedValues,
    key_name: Text
  ): async Result.Result<Types.KaspaTransaction, Text> {
    switch (Sighash.calculate_sighash_ecdsa(tx, input_index, utxo, hash_type, reused_values)) {
      case (null) {
        #err("Failed to compute ECDSA sighash")
      };
      case (?sighash) {
        Debug.print("   -> Signing ECDSA sighash: " # hex_from_array(sighash));
        switch (await sign_ecdsa_sighash(sighash, key_name)) {
          case (#ok(signature)) {
            switch (await generate_keypair(key_name)) {
              case (#ok(keypair)) {
                let signature_script = create_signature_script(signature, keypair.publicKey);
                // Update transaction with new signatureScript
                let new_inputs = Array.map<Types.KaspaTransactionInput, Types.KaspaTransactionInput>(
                  tx.inputs,
                  func (input, i): Types.KaspaTransactionInput {
                    if (i == input_index) {
                      { input with signatureScript = hex_from_array(signature_script) }
                    } else {
                      input
                    }
                  }
                );
                #ok({ tx with inputs = new_inputs })
              };
              case (#err(err)) {
                #err(err)
              };
            }
          };
          case (#err(err)) {
            #err(err)
          };
        }
      };
    }
  };
};