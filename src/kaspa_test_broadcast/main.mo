import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Text "mo:base/Text";

import KaspaBroadcaster "./broadcast";

// Main canister for Kaspa integration
persistent actor KaspaTestBroadcast {
    
    // Initialize the broadcaster
    private transient let broadcaster = KaspaBroadcaster.KaspaBroadcaster();
    
    // Store transaction history (optional)
    private var transactionHistory: [(Text, KaspaBroadcaster.KaspaTransaction)] = [];
    
    // Example transaction creation and broadcasting
    public func submitTransaction(
        inputs: [KaspaBroadcaster.TransactionInput],
        outputs: [KaspaBroadcaster.TransactionOutput],
        network: KaspaBroadcaster.Network
    ): async Result.Result<Text, Text> {
        
        // Create transaction
        let transaction: KaspaBroadcaster.KaspaTransaction = {
            version = 1;
            inputs = inputs;
            outputs = outputs;
            lockTime = 0;
            subnetworkId = Blob.fromArray([]);
            gas = 10000; // Default gas amount
            payload = Blob.fromArray([]);
        };
        
        // Validate transaction
        if (not broadcaster.validateTransaction(transaction)) {
            return #err("Invalid transaction structure");
        };
        
        // Broadcast to network
        let result = await broadcaster.broadcastTransaction(
            transaction,
            network,
            false // allowOrphan
        );
        
        switch (result) {
            case (#ok(txId)) {
                // Store in history
                let historyEntry = (txId, transaction);
                transactionHistory := Array.append(transactionHistory, [historyEntry]);
                #ok(txId)
            };
            case (#err(error)) {
                #err(error)
            };
        }
    };
    
    // Helper function to create a simple P2PK transaction
    public func createSimpleTransaction(
        fromTxId: Text,
        fromIndex: Nat32,
        toAddress: Text,
        amount: Nat64,
        signatureScript: Blob
    ): async {inputs: [KaspaBroadcaster.TransactionInput]; outputs: [KaspaBroadcaster.TransactionOutput]} {
        
        let input: KaspaBroadcaster.TransactionInput = {
            previousOutpoint = {
                transactionId = fromTxId;
                index = fromIndex;
            };
            signatureScript = signatureScript;
            sequence = 0xffffffff;
        };
        
        let output: KaspaBroadcaster.TransactionOutput = {
            amount = amount;
            scriptPubKey = {
                version = 1;
                scriptPublicKey = addressToScriptPubKey(toAddress);
            };
        };
        
        {inputs = [input]; outputs = [output]}
    };
    
    // Convert Kaspa address to scriptPubKey (simplified)
    private func addressToScriptPubKey(address: Text): Blob {
        // This is highly simplified - you need proper address decoding
        // Kaspa addresses are bech32 encoded and need proper conversion
        Text.encodeUtf8(address)
    };
    
    // Test network connectivity
    public func testConnection(network: KaspaBroadcaster.Network): async Result.Result<Text, Text> {
        await broadcaster.getNetworkInfo(network)
    };

    // New test function with hardcoded values for simple execution
    public func runBroadcastTest(): async Result.Result<Text, Text> {
        Debug.print("--- Starting Broadcast Test ---");

        // These are example values. You MUST replace them with valid, spendable UTXOs from the testnet.
        // 1. Get a testnet address and some funds from a faucet.
        // 2. Find a transaction ID and index (UTXO) that you can spend.
        // 3. Craft the correct signature script.

        let fromTxId = "0000000000000000000000000000000000000000000000000000000000000000"; // REPLACE
        let fromIndex: Nat32 = 0;
        let amount: Nat64 = 10000; // Small amount in sompis
        
        // This should be the raw public key script for the destination address
        let toAddressScript = ""; // REPLACE with a real script public key
        
        // This is a placeholder signature. A real signature must be created offline
        // by signing the transaction hash with the private key corresponding to the UTXO.
        let signatureScript = Blob.fromArray([]); // REPLACE with a real signature script

        Debug.print("Broadcasting with placeholder data. This is expected to fail unless you provide a valid, signed UTXO.");

        await createAndBroadcastTransaction(
            fromTxId,
            fromIndex,
            toAddressScript,
            amount,
            signatureScript,
            #testnet
        )
    };
    
    // Get transaction history
    public query func getTransactionHistory(): async [(Text, KaspaBroadcaster.KaspaTransaction)] {
        transactionHistory
    };
    
    // Health check endpoint
    public query func health(): async Bool {
        true
    };
    
    // Complete transaction flow - create and broadcast
    public func createAndBroadcastTransaction(
        fromTxId: Text,
        fromIndex: Nat32,
        toAddress: Text,
        amount: Nat64,
        signatureScript: Blob,
        network: KaspaBroadcaster.Network
    ): async Result.Result<Text, Text> {
        
        // Create transaction components
        let txComponents = await createSimpleTransaction(
            fromTxId,
            fromIndex,
            toAddress,
            amount,
            signatureScript
        );
        
        // Broadcast the transaction
        await submitTransaction(
            txComponents.inputs,
            txComponents.outputs,
            network
        )
    };
}