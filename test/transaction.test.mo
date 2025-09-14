import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Error "mo:base/Error";

import Transaction "../src/kaspa/transaction";
import Types "../src/kaspa/types";

persistent actor {

  // --- Tests for build_transaction ---
  public func runTests() : async () {
    Debug.print("\n--- Running Transaction.build_transaction tests ---\n");

    // Test 1: Successful build with one input and one output (exact amount after fee)
    func test_build_transaction_success_exact() {
      Debug.print("🧪 test_build_transaction_success_exact...");

      let utxo : Types.UTXO = {
        transactionId = "abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234";
        index = 0;
        amount = 600_000;
        scriptPublicKey = "76a914abcdefabcdefabcdefabcdefabcdefabcdef88ac";
        scriptVersion = 0;
        address = "kaspa:exampleaddress";
      };

      let recipient_script = "76a9140123456789abcdef0123456789abcdef88ac";
      let output_amount : Nat64 = 500_000;
      let fee : Nat64 = 100_000;
      let change_script = recipient_script; // Using recipient_script as change for test

      let tx = Transaction.build_transaction(utxo, recipient_script, output_amount, fee, change_script);

      // Assert all transaction fields for correctness
      assert (tx.version == 0);
      assert (tx.inputs.size() == 1);
      assert (tx.inputs[0].previousOutpoint.transactionId == utxo.transactionId);
      assert (tx.inputs[0].previousOutpoint.index == utxo.index);
      assert (tx.inputs[0].signatureScript == "");
      assert (tx.inputs[0].sequence == 0);
      assert (tx.inputs[0].sigOpCount == 1);
      assert (tx.outputs.size() == 1); // No change (600,000 = 500,000 + 100,000)
      assert (tx.outputs[0].amount == output_amount);
      assert (tx.outputs[0].scriptPublicKey.version == 0);
      assert (tx.outputs[0].scriptPublicKey.scriptPublicKey == recipient_script);
      assert (tx.lockTime == 0);
      assert (tx.subnetworkId == "0000000000000000000000000000000000000000");
      assert (tx.gas == 0);
      assert (tx.payload == "");

      // Serialize and check against expected JSON (no signature, single output)
      let expected_json = "{\"transaction\":{\"version\":0,\"inputs\":[{\"previousOutpoint\":{\"transactionId\":\"abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234\",\"index\":0},\"signatureScript\":\"\",\"sequence\":0,\"sigOpCount\":1}],\"outputs\":[{\"amount\":500000,\"scriptPublicKey\":{\"version\":0,\"scriptPublicKey\":\"76a9140123456789abcdef0123456789abcdef88ac\"}}],\"lockTime\":0,\"subnetworkId\":\"0000000000000000000000000000000000000000\",\"gas\":0,\"payload\":\"\"}}";
      let serialized = Transaction.serialize_transaction(tx);
      assert (serialized == expected_json);

      Debug.print("   ✅ Passed test_build_transaction_success_exact!");
    };

    // Test 2: Successful build with one input and two outputs (recipient + change)
    func test_build_transaction_success_larger_fee() {
      Debug.print("🧪 test_build_transaction_success_larger_fee...");

      let utxo : Types.UTXO = {
        transactionId = "efgh5678efgh5678efgh5678efgh5678efgh5678efgh5678efgh5678efgh5678";
        index = 1;
        amount = 1_000_000;
        scriptPublicKey = "76a914fedcbafedcbafedcbafedcbafedcbafedcba88ac";
        scriptVersion = 0;
        address = "kaspa:exampleaddress2";
      };

      let recipient_script = "76a9149876543210fedcba9876543210fedcba88ac";
      let output_amount : Nat64 = 500_000;
      let fee : Nat64 = 100_000; // Change = 1,000,000 - 500,000 - 100,000 = 400,000
      let change_script = "76a914fedcbafedcbafedcbafedcbafedcbafedcba88ac"; // Sender's script

      let tx = Transaction.build_transaction(utxo, recipient_script, output_amount, fee, change_script);

      // Assert key fields
      assert (tx.version == 0);
      assert (tx.inputs.size() == 1);
      assert (tx.inputs[0].previousOutpoint.transactionId == utxo.transactionId);
      assert (tx.inputs[0].previousOutpoint.index == utxo.index);
      assert (tx.inputs[0].signatureScript == "");
      assert (tx.inputs[0].sequence == 0);
      assert (tx.inputs[0].sigOpCount == 1);
      assert (tx.outputs.size() == 2); // Expect recipient + change
      assert (tx.outputs[0].amount == output_amount);
      assert (tx.outputs[0].scriptPublicKey.version == 0);
      assert (tx.outputs[0].scriptPublicKey.scriptPublicKey == recipient_script);
      assert (tx.outputs[1].amount == 400_000); // Change amount
      assert (tx.outputs[1].scriptPublicKey.version == 0);
      assert (tx.outputs[1].scriptPublicKey.scriptPublicKey == change_script);
      assert (tx.lockTime == 0);
      assert (tx.subnetworkId == "0000000000000000000000000000000000000000");
      assert (tx.gas == 0);
      assert (tx.payload == "");

      // Serialize and check against expected JSON
      let expected_json = "{\"transaction\":{\"version\":0,\"inputs\":[{\"previousOutpoint\":{\"transactionId\":\"efgh5678efgh5678efgh5678efgh5678efgh5678efgh5678efgh5678efgh5678\",\"index\":1},\"signatureScript\":\"\",\"sequence\":0,\"sigOpCount\":1}],\"outputs\":[{\"amount\":500000,\"scriptPublicKey\":{\"version\":0,\"scriptPublicKey\":\"76a9149876543210fedcba9876543210fedcba88ac\"}},{\"amount\":400000,\"scriptPublicKey\":{\"version\":0,\"scriptPublicKey\":\"76a914fedcbafedcbafedcbafedcbafedcbafedcba88ac\"}}],\"lockTime\":0,\"subnetworkId\":\"0000000000000000000000000000000000000000\",\"gas\":0,\"payload\":\"\"}}";
      let serialized = Transaction.serialize_transaction(tx);
      assert (serialized == expected_json);

      Debug.print("   ✅ Passed test_build_transaction_success_larger_fee!");
    };

    // Test 3: Insufficient funds returns empty transaction
    func test_build_transaction_insufficient() {
      Debug.print("🧪 test_build_transaction_insufficient...");

      let utxo : Types.UTXO = {
        transactionId = "ijkl9012ijkl9012ijkl9012ijkl9012ijkl9012ijkl9012ijkl9012ijkl9012";
        index = 0;
        amount = 500_000; // Less than output + fee
        scriptPublicKey = "76a914abcdefabcdefabcdefabcdefabcdefabcdef88ac";
        scriptVersion = 0;
        address = "kaspa:exampleaddress";
      };

      let recipient_script = "76a9140123456789abcdef0123456789abcdef88ac";
      let output_amount : Nat64 = 500_000;
      let fee : Nat64 = 100_000;
      let change_script = recipient_script;

      let tx = Transaction.build_transaction(utxo, recipient_script, output_amount, fee, change_script);

      // Assert empty transaction fields
      assert (tx.version == 0);
      assert (tx.inputs.size() == 0);
      assert (tx.outputs.size() == 0);
      assert (tx.lockTime == 0);
      assert (tx.subnetworkId == "0000000000000000000000000000000000000000");
      assert (tx.gas == 0);
      assert (tx.payload == "");

      // Serialize and check against expected empty JSON
      let expected_json = "{\"transaction\":{\"version\":0,\"inputs\":[],\"outputs\":[],\"lockTime\":0,\"subnetworkId\":\"0000000000000000000000000000000000000000\",\"gas\":0,\"payload\":\"\"}}";
      let serialized = Transaction.serialize_transaction(tx);
      assert (serialized == expected_json);

      Debug.print("   ✅ Passed test_build_transaction_insufficient!");
    };

    // Test 4: Edge case - Minimum exact amount (output + fee == input)
    func test_build_transaction_edge_min_exact() : async () {
      Debug.print("🧪 test_build_transaction_edge_min_exact...");
      try {
        let utxo : Types.UTXO = {
          transactionId = "mnop3456mnop3456mnop3456mnop3456mnop3456mnop3456mnop3456mnop3456";
          index = 2;
          amount = 100_000;
          scriptPublicKey = "76a9141234567890abcdef1234567890abcdef88ac";
          scriptVersion = 0;
          address = "kaspa:exampleaddress3";
        };

        let recipient_script = "76a914fedcba9876543210fedcba987654321088ac";
        let output_amount : Nat64 = 50_000;
        let fee : Nat64 = 50_000;
        let change_script = recipient_script;

        let tx = Transaction.build_transaction(utxo, recipient_script, output_amount, fee, change_script);

        Debug.print("   Debug: inputs.size() = " # Nat.toText(tx.inputs.size()));
        Debug.print("   Debug: outputs.size() = " # Nat.toText(tx.outputs.size()));
        if (tx.outputs.size() > 0) {
          Debug.print("   Debug: outputs[0].amount = " # Nat64.toText(tx.outputs[0].amount));
        };

        if (tx.inputs.size() != 1) {
          Debug.print("   ❌ Failed: Expected 1 input, got " # Nat.toText(tx.inputs.size()));
          return;
        };
        if (tx.outputs.size() != 1) {
          Debug.print("   ❌ Failed: Expected 1 output, got " # Nat.toText(tx.outputs.size()));
          return;
        };
        if (tx.outputs[0].amount != 50_000) {
          Debug.print("   ❌ Failed: Expected output amount 50,000, got " # Nat64.toText(tx.outputs[0].amount));
          return;
        };

        Debug.print("   ✅ Passed test_build_transaction_edge_min_exact!");
      } catch (e) {
        Debug.print("   ❌ Test trapped: " # Error.message(e));
      };
    };

    // Test 5: Edge case - Zero output amount (should still build if input >= fee)
    func test_build_transaction_edge_zero_output() : async () {
      Debug.print("🧪 test_build_transaction_edge_zero_output...");
      try {
        let utxo : Types.UTXO = {
          transactionId = "qrst7890qrst7890qrst7890qrst7890qrst7890qrst7890qrst7890qrst7890";
          index = 3;
          amount = 100_000;
          scriptPublicKey = "76a914abcdefabcdefabcdefabcdefabcdefabcdef88ac";
          scriptVersion = 0;
          address = "kaspa:exampleaddress4";
        };

        let recipient_script = "76a9140123456789abcdef0123456789abcdef88ac";
        let output_amount : Nat64 = 0;
        let fee : Nat64 = 50_000;
        let change_script = recipient_script;

        let tx = Transaction.build_transaction(utxo, recipient_script, output_amount, fee, change_script);

        Debug.print("   Debug: inputs.size() = " # Nat.toText(tx.inputs.size()));
        Debug.print("   Debug: outputs.size() = " # Nat.toText(tx.outputs.size()));
        if (tx.outputs.size() > 0) {
          Debug.print("   Debug: outputs[0].amount = " # Nat64.toText(tx.outputs[0].amount));
        };
        if (tx.outputs.size() > 1) {
          Debug.print("   Debug: outputs[1].amount = " # Nat64.toText(tx.outputs[1].amount));
        };

        if (tx.inputs.size() != 1) {
          Debug.print("   ❌ Failed: Expected 1 input, got " # Nat.toText(tx.inputs.size()));
          return;
        };
        if (tx.outputs.size() != 2) {
          Debug.print("   ❌ Failed: Expected 2 outputs, got " # Nat.toText(tx.outputs.size()));
          return;
        };
        if (tx.outputs[0].amount != 0) {
          Debug.print("   ❌ Failed: Expected first output amount 0, got " # Nat64.toText(tx.outputs[0].amount));
          return;
        };
        if (tx.outputs[1].amount != 50_000) {
          Debug.print("   ❌ Failed: Expected second output amount 50,000, got " # Nat64.toText(tx.outputs[1].amount));
          return;
        };
        if (tx.outputs[0].scriptPublicKey.scriptPublicKey != recipient_script) {
          Debug.print("   ❌ Failed: Incorrect recipient scriptPublicKey");
          return;
        };
        if (tx.outputs[1].scriptPublicKey.scriptPublicKey != change_script) {
          Debug.print("   ❌ Failed: Incorrect change scriptPublicKey");
          return;
        };

        Debug.print("   ✅ Passed test_build_transaction_edge_zero_output!");
      } catch (e) {
        Debug.print("   ❌ Test trapped: " # Error.message(e));
      };
    };

    // Test 6: Serialize transaction with various configurations
    func test_serialize_transaction() {
      Debug.print("🧪 test_serialize_transaction...");

      // Subtest 1: Single input, single output with signature script
      do {
        Debug.print("   Subtest 1: Single input, single output with signature script...");
        let tx : Types.KaspaTransaction = {
          version = 0;
          inputs = [{
            previousOutpoint = {
              transactionId = "abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234";
              index = 0;
            };
            signatureScript = "41107429d672671b737dbfcff40794c88223c992e4f3f8428a2c71c1b53d51d1981ae7a739ac3f58e084e7a31f106dc1b028b7fa57fe71040d6d7071fcef00481101";
            sequence = 0;
            sigOpCount = 1;
          }];
          outputs = [{
            amount = 500_000;
            scriptPublicKey = {
              version = 0;
              scriptPublicKey = "76a9140123456789abcdef0123456789abcdef88ac";
            };
          }];
          lockTime = 0;
          subnetworkId = "0000000000000000000000000000000000000000";
          gas = 0;
          payload = "";
        };

        let expected_json = "{\"transaction\":{\"version\":0,\"inputs\":[{\"previousOutpoint\":{\"transactionId\":\"abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234\",\"index\":0},\"signatureScript\":\"41107429d672671b737dbfcff40794c88223c992e4f3f8428a2c71c1b53d51d1981ae7a739ac3f58e084e7a31f106dc1b028b7fa57fe71040d6d7071fcef00481101\",\"sequence\":0,\"sigOpCount\":1}],\"outputs\":[{\"amount\":500000,\"scriptPublicKey\":{\"version\":0,\"scriptPublicKey\":\"76a9140123456789abcdef0123456789abcdef88ac\"}}],\"lockTime\":0,\"subnetworkId\":\"0000000000000000000000000000000000000000\",\"gas\":0,\"payload\":\"\"}}";
        let serialized = Transaction.serialize_transaction(tx);
        assert (serialized == expected_json);
        Debug.print("   ✅ Passed subtest 1!");
      };

      // Subtest 2: Multiple inputs and outputs
      do {
        Debug.print("   Subtest 2: Multiple inputs and outputs...");
        let tx : Types.KaspaTransaction = {
          version = 1;
          inputs = [
            {
              previousOutpoint = {
                transactionId = "efgh5678efgh5678efgh5678efgh5678efgh5678efgh5678efgh5678efgh5678";
                index = 1;
              };
              signatureScript = "41107429d672671b737dbfcff40794c88223c992e4f3f8428a2c71c1b53d51d1981ae7a739ac3f58e084e7a31f106dc1b028b7fa57fe71040d6d7071fcef00481101";
              sequence = 1;
              sigOpCount = 2;
            },
            {
              previousOutpoint = {
                transactionId = "ijkl9012ijkl9012ijkl9012ijkl9012ijkl9012ijkl9012ijkl9012ijkl9012";
                index = 2;
              };
              signatureScript = "";
              sequence = 0;
              sigOpCount = 1;
            },
          ];
          outputs = [
            {
              amount = 300_000;
              scriptPublicKey = {
                version = 0;
                scriptPublicKey = "76a9149876543210fedcba9876543210fedcba88ac";
              };
            },
            {
              amount = 200_000;
              scriptPublicKey = {
                version = 0;
                scriptPublicKey = "76a914fedcbafedcbafedcbafedcbafedcbafedcba88ac";
              };
            },
          ];
          lockTime = 1000;
          subnetworkId = "1111111111111111111111111111111111111111";
          gas = 500;
          payload = "48656c6c6f"; // "Hello" in hex
        };

        let expected_json = "{\"transaction\":{\"version\":1,\"inputs\":[{\"previousOutpoint\":{\"transactionId\":\"efgh5678efgh5678efgh5678efgh5678efgh5678efgh5678efgh5678efgh5678\",\"index\":1},\"signatureScript\":\"41107429d672671b737dbfcff40794c88223c992e4f3f8428a2c71c1b53d51d1981ae7a739ac3f58e084e7a31f106dc1b028b7fa57fe71040d6d7071fcef00481101\",\"sequence\":1,\"sigOpCount\":2},{\"previousOutpoint\":{\"transactionId\":\"ijkl9012ijkl9012ijkl9012ijkl9012ijkl9012ijkl9012ijkl9012ijkl9012\",\"index\":2},\"signatureScript\":\"\",\"sequence\":0,\"sigOpCount\":1}],\"outputs\":[{\"amount\":300000,\"scriptPublicKey\":{\"version\":0,\"scriptPublicKey\":\"76a9149876543210fedcba9876543210fedcba88ac\"}},{\"amount\":200000,\"scriptPublicKey\":{\"version\":0,\"scriptPublicKey\":\"76a914fedcbafedcbafedcbafedcbafedcbafedcba88ac\"}}],\"lockTime\":1000,\"subnetworkId\":\"1111111111111111111111111111111111111111\",\"gas\":500,\"payload\":\"48656c6c6f\"}}";
        let serialized = Transaction.serialize_transaction(tx);
        assert (serialized == expected_json);
        Debug.print("   ✅ Passed subtest 2!");
      };

      // Subtest 3: Empty transaction
      do {
        Debug.print("   Subtest 3: Empty transaction...");
        let tx : Types.KaspaTransaction = {
          version = 0;
          inputs = [];
          outputs = [];
          lockTime = 0;
          subnetworkId = "0000000000000000000000000000000000000000";
          gas = 0;
          payload = "";
        };

        let expected_json = "{\"transaction\":{\"version\":0,\"inputs\":[],\"outputs\":[],\"lockTime\":0,\"subnetworkId\":\"0000000000000000000000000000000000000000\",\"gas\":0,\"payload\":\"\"}}";
        let serialized = Transaction.serialize_transaction(tx);
        assert (serialized == expected_json);
        Debug.print("   ✅ Passed subtest 3!");
      };

      Debug.print("   ✅ Passed test_serialize_transaction!");
    };

    // Run all tests
    test_build_transaction_success_exact();
    test_build_transaction_success_larger_fee();
    test_build_transaction_insufficient();
    await test_build_transaction_edge_min_exact();
    await test_build_transaction_edge_zero_output();
    test_serialize_transaction();

    Debug.print("\n--- All Transaction.build_transaction tests completed! ---\n");
  };
};
