import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Char "mo:base/Char";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";

import Address "../src/kaspa/address";
import Transaction "../src/kaspa/transaction";
import Types "../src/kaspa/types";
import Utils "../src/utils/utils";

persistent actor {

  // --- Tests for build_transaction ---
  public func runTests(): async () {
    Debug.print("\n--- Running Transaction.build_transaction tests ---\n");

    // Test 1: Successful build with one input and one output (exact amount after fee)
    func test_build_transaction_success_exact() {
      Debug.print("🧪 test_build_transaction_success_exact...");

      let utxo: Types.UTXO = {
        transactionId = "abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234"; // 64-char hex
        index = 0;
        amount = 600_000;
        scriptPublicKey = "76a914abcdefabcdefabcdefabcdefabcdefabcdef88ac";
        scriptVersion = 0;
        address = "kaspa:exampleaddress";
      };

      let recipient_script = "76a9140123456789abcdef0123456789abcdef88ac";
      let output_amount: Nat64 = 500_000;
      let fee: Nat64 = 100_000;

      let tx = Transaction.build_transaction(utxo, recipient_script, output_amount, fee);

      // Assert all transaction fields for correctness
      assert(tx.version == 0);
      assert(tx.inputs.size() == 1);
      assert(tx.inputs[0].previousOutpoint.transactionId == utxo.transactionId);
      assert(tx.inputs[0].previousOutpoint.index == utxo.index);
      assert(tx.inputs[0].signatureScript == "");
      assert(tx.inputs[0].sequence == 0);
      assert(tx.inputs[0].sigOpCount == 1);
      assert(tx.outputs.size() == 1);
      assert(tx.outputs[0].amount == output_amount);
      assert(tx.outputs[0].scriptPublicKey.version == 0);
      assert(tx.outputs[0].scriptPublicKey.scriptPublicKey == recipient_script);
      assert(tx.lockTime == 0);
      assert(tx.subnetworkId == "0000000000000000000000000000000000000000");
      assert(tx.gas == 0);
      assert(tx.payload == "");

      // Serialize and check against expected JSON (no signature, single output)
      let expected_json = "{\"transaction\":{\"version\":0,\"inputs\":[{\"previousOutpoint\":{\"transactionId\":\"abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234\",\"index\":0},\"signatureScript\":\"\",\"sequence\":0,\"sigOpCount\":1}],\"outputs\":[{\"amount\":500000,\"scriptPublicKey\":\"76a9140123456789abcdef0123456789abcdef88ac\"}],\"lockTime\":0,\"subnetworkId\":\"0000000000000000000000000000000000000000\",\"gas\":0,\"payload\":\"\"}}";
      let serialized = Transaction.serialize_transaction(tx);
      assert(serialized == expected_json);

      Debug.print("   ✅ Passed test_build_transaction_success_exact!");
    };

    // Test 2: Successful build with implicit larger fee (no change output)
    func test_build_transaction_success_larger_fee() {
      Debug.print("🧪 test_build_transaction_success_larger_fee...");

      let utxo: Types.UTXO = {
        transactionId = "efgh5678efgh5678efgh5678efgh5678efgh5678efgh5678efgh5678efgh5678";
        index = 1;
        amount = 1_000_000;
        scriptPublicKey = "76a914fedcbafedcbafedcbafedcbafedcbafedcba88ac";
        scriptVersion = 0;
        address = "kaspa:exampleaddress2";
      };

      let recipient_script = "76a9149876543210fedcba9876543210fedcba88ac";
      let output_amount: Nat64 = 500_000;
      let fee: Nat64 = 100_000; // Implicit fee will be 500_000 (> 100_000 min)

      let tx = Transaction.build_transaction(utxo, recipient_script, output_amount, fee);

      // Assert key fields
      assert(tx.version == 0);
      assert(tx.inputs.size() == 1);
      assert(tx.inputs[0].previousOutpoint.transactionId == utxo.transactionId);
      assert(tx.inputs[0].previousOutpoint.index == utxo.index);
      assert(tx.inputs[0].signatureScript == "");
      assert(tx.inputs[0].sequence == 0);
      assert(tx.inputs[0].sigOpCount == 1);
      assert(tx.outputs.size() == 1);
      assert(tx.outputs[0].amount == output_amount);
      assert(tx.outputs[0].scriptPublicKey.version == 0);
      assert(tx.outputs[0].scriptPublicKey.scriptPublicKey == recipient_script);
      assert(tx.lockTime == 0);
      assert(tx.subnetworkId == "0000000000000000000000000000000000000000");
      assert(tx.gas == 0);
      assert(tx.payload == "");

      // Serialize and check against expected JSON
      let expected_json = "{\"transaction\":{\"version\":0,\"inputs\":[{\"previousOutpoint\":{\"transactionId\":\"efgh5678efgh5678efgh5678efgh5678efgh5678efgh5678efgh5678efgh5678\",\"index\":1},\"signatureScript\":\"\",\"sequence\":0,\"sigOpCount\":1}],\"outputs\":[{\"amount\":500000,\"scriptPublicKey\":\"76a9149876543210fedcba9876543210fedcba88ac\"}],\"lockTime\":0,\"subnetworkId\":\"0000000000000000000000000000000000000000\",\"gas\":0,\"payload\":\"\"}}";
      let serialized = Transaction.serialize_transaction(tx);
      assert(serialized == expected_json);

      Debug.print("   ✅ Passed test_build_transaction_success_larger_fee!");
    };

    // Test 3: Insufficient funds returns empty transaction
    func test_build_transaction_insufficient() {
      Debug.print("🧪 test_build_transaction_insufficient...");

      let utxo: Types.UTXO = {
        transactionId = "ijkl9012ijkl9012ijkl9012ijkl9012ijkl9012ijkl9012ijkl9012ijkl9012";
        index = 0;
        amount = 500_000; // Less than output + fee
        scriptPublicKey = "76a914abcdefabcdefabcdefabcdefabcdefabcdef88ac";
        scriptVersion = 0;
        address = "kaspa:exampleaddress";
      };

      let recipient_script = "76a9140123456789abcdef0123456789abcdef88ac";
      let output_amount: Nat64 = 500_000;
      let fee: Nat64 = 100_000;

      let tx = Transaction.build_transaction(utxo, recipient_script, output_amount, fee);

      // Assert empty transaction fields
      assert(tx.version == 0);
      assert(tx.inputs.size() == 0);
      assert(tx.outputs.size() == 0);
      assert(tx.lockTime == 0);
      assert(tx.subnetworkId == "0000000000000000000000000000000000000000");
      assert(tx.gas == 0);
      assert(tx.payload == "");

      // Serialize and check against expected empty JSON
      let expected_json = "{\"transaction\":{\"version\":0,\"inputs\":[],\"outputs\":[],\"lockTime\":0,\"subnetworkId\":\"0000000000000000000000000000000000000000\",\"gas\":0,\"payload\":\"\"}}";
      let serialized = Transaction.serialize_transaction(tx);
      assert(serialized == expected_json);

      Debug.print("   ✅ Passed test_build_transaction_insufficient!");
    };

    // Test 4: Edge case - Minimum exact amount (output + fee == input)
    func test_build_transaction_edge_min_exact() {
      Debug.print("🧪 test_build_transaction_edge_min_exact...");

      let utxo: Types.UTXO = {
        transactionId = "mnop3456mnop3456mnop3456mnop3456mnop3456mnop3456mnop3456mnop3456";
        index = 2;
        amount = 100_000;
        scriptPublicKey = "76a9141234567890abcdef1234567890abcdef88ac";
        scriptVersion = 0;
        address = "kaspa:exampleaddress3";
      };

      let recipient_script = "76a914fedcba9876543210fedcba987654321088ac";
      let output_amount: Nat64 = 50_000;
      let fee: Nat64 = 50_000;

      let tx = Transaction.build_transaction(utxo, recipient_script, output_amount, fee);

      assert(tx.inputs.size() == 1);
      assert(tx.outputs.size() == 1);
      assert(tx.outputs[0].amount == 50_000);

      Debug.print("   ✅ Passed test_build_transaction_edge_min_exact!");
    };

    // Test 5: Edge case - Zero output amount (should still build if input >= fee)
    func test_build_transaction_edge_zero_output() {
      Debug.print("🧪 test_build_transaction_edge_zero_output...");

      let utxo: Types.UTXO = {
        transactionId = "qrst7890qrst7890qrst7890qrst7890qrst7890qrst7890qrst7890qrst7890";
        index = 3;
        amount = 100_000;
        scriptPublicKey = "76a914abcdefabcdefabcdefabcdefabcdefabcdef88ac";
        scriptVersion = 0;
        address = "kaspa:exampleaddress4";
      };

      let recipient_script = "76a9140123456789abcdef0123456789abcdef88ac";
      let output_amount: Nat64 = 0;
      let fee: Nat64 = 50_000;

      let tx = Transaction.build_transaction(utxo, recipient_script, output_amount, fee);

      assert(tx.inputs.size() == 1);
      assert(tx.outputs.size() == 1);
      assert(tx.outputs[0].amount == 0);

      Debug.print("   ✅ Passed test_build_transaction_edge_zero_output!");
    };

    // Run all tests
    test_build_transaction_success_exact();
    test_build_transaction_success_larger_fee();
    test_build_transaction_insufficient();
    test_build_transaction_edge_min_exact();
    test_build_transaction_edge_zero_output();

    Debug.print("\n--- All Transaction.build_transaction tests completed! ---\n");
  };
};