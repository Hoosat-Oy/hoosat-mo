import Debug "mo:base/Debug";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Nat8 "mo:base/Nat8";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Nat "mo:base/Nat";
import Bool "mo:base/Bool";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Error "mo:base/Error";
import Cycles "mo:base/ExperimentalCycles";

module KaspaBroadcaster {

    // Network endpoints
    public let KASPA_MAINNET_RPC = "https://api.kaspa.org";
    public let KASPA_TESTNET_RPC = "https://api-tn10.kaspa.org";
    
    // Alternative endpoints (you may need to run your own node)
    public let LOCAL_MAINNET_RPC = "http://127.0.0.1:18110";
    public let LOCAL_TESTNET_RPC = "http://127.0.0.1:18210";

    public type Network = {
        #mainnet;
        #testnet;
    };

    // Kaspa transaction structure (simplified)
    public type KaspaTransaction = {
        version: Nat16;
        inputs: [TransactionInput];
        outputs: [TransactionOutput];
        lockTime: Nat64;
        subnetworkId: Blob;
        gas: Nat64;
        payload: Blob;
    };

    public type TransactionInput = {
        previousOutpoint: Outpoint;
        signatureScript: Blob;
        sequence: Nat64;
    };

    public type TransactionOutput = {
        amount: Nat64;
        scriptPubKey: ScriptPubKey;
    };

    public type Outpoint = {
        transactionId: Text;
        index: Nat32;
    };

    public type ScriptPubKey = {
        version: Nat16;
        scriptPublicKey: Blob;
    };

    // RPC Request/Response types
    public type SubmitTransactionRequest = {
        method: Text;
        params: {
            transaction: KaspaTransaction;
            allowOrphan: Bool;
        };
        id: Text;
        jsonrpc: Text;
    };

    public type SubmitTransactionResponse = {
        result: ?{
            transactionId: Text;
        };
        error: ?{
            code: Int;
            message: Text;
        };
        id: Text;
        jsonrpc: Text;
    };

    public type BroadcastResult = Result.Result<Text, Text>;

    // HTTP Outcall types for ICP management canister
    public type HttpHeader = {
        name: Text;
        value: Text;
    };

    public type HttpMethod = {
        #get;
        #post;
        #head;
    };

    public type HttpRequest = {
        url: Text;
        method: HttpMethod;
        headers: [HttpHeader];
        body: ?Blob;
        transform: ?{
            function: shared query HttpResponse -> async HttpResponse;
            context: Blob;
        };
    };

    public type HttpResponse = {
        status: Nat;
        headers: [HttpHeader];
        body: Blob;
    };

    // Management canister interface for HTTP outcalls
    private let ic = actor("aaaaa-aa") : actor {
        http_request: HttpRequest -> async HttpResponse;
    };

    public class KaspaBroadcaster() {
        
        private func getEndpoint(network: Network): Text {
            switch (network) {
                case (#mainnet) { KASPA_MAINNET_RPC };
                case (#testnet) { KASPA_TESTNET_RPC };
            }
        };

        // Convert transaction to JSON for RPC call
        private func transactionToJson(tx: KaspaTransaction): Text {
            // This is a simplified version - you'll need proper JSON serialization
            // Consider using a JSON library or building the JSON string manually
            let inputs = Array.foldLeft<TransactionInput, Text>(
                tx.inputs, 
                "", 
                func(acc, input) = acc # "," # inputToJson(input)
            );
            
            let outputs = Array.foldLeft<TransactionOutput, Text>(
                tx.outputs, 
                "", 
                func(acc, output) = acc # "," # outputToJson(output)
            );

            "{"
            # "\"version\":" # Nat16.toText(tx.version) # ","
            # "\"inputs\":[" # inputs # "],"
            # "\"outputs\":[" # outputs # "],"
            # "\"lockTime\":" # Nat64.toText(tx.lockTime) # ","
            # "\"gas\":" # Nat64.toText(tx.gas)
            # "}"
        };

        private func inputToJson(input: TransactionInput): Text {
            "{"
            # "\"previousOutpoint\":{"
            # "\"transactionId\":\"" # input.previousOutpoint.transactionId # "\","
            # "\"index\":" # Nat32.toText(input.previousOutpoint.index)
            # "},"
            # "\"signatureScript\":\"" # blobToHex(input.signatureScript) # "\","
            # "\"sequence\":" # Nat64.toText(input.sequence)
            # "}"
        };

        private func outputToJson(output: TransactionOutput): Text {
            "{"
            # "\"amount\":" # Nat64.toText(output.amount) # ","
            # "\"scriptPubKey\":{"
            # "\"version\":" # Nat16.toText(output.scriptPubKey.version) # ","
            # "\"scriptPublicKey\":\"" # blobToHex(output.scriptPubKey.scriptPublicKey) # "\""
            # "}"
            # "}"
        };

        private func blobToHex(blob: Blob): Text {
            let bytes = Blob.toArray(blob);
            let hexChars = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"];
            Array.foldLeft<Nat8, Text>(bytes, "", func(acc, byte) {
                let high = byte / 16;
                let low = byte % 16;
                acc # hexChars[Nat8.toNat(high)] # hexChars[Nat8.toNat(low)]
            })
        };

        // Main function to broadcast transaction
        public func broadcastTransaction(
            tx: KaspaTransaction, 
            network: Network,
            allowOrphan: Bool
        ): async BroadcastResult {
            
            let endpoint = getEndpoint(network);
            let txJson = transactionToJson(tx);
            
            let requestBody = "{"
                # "\"jsonrpc\":\"2.0\","
                # "\"method\":\"submitTransaction\","
                # "\"params\":{"
                # "\"transaction\":" # txJson # ","
                # "\"allowOrphan\":" # Bool.toText(allowOrphan)
                # "},"
                # "\"id\":\"" # Int.toText(Time.now()) # "\""
                # "}";

            let headers: [HttpHeader] = [
                { name = "Content-Type"; value = "application/json" },
                { name = "Accept"; value = "application/json" }
            ];

            // HTTP outcall configuration using ICP management canister
            let httpRequest: HttpRequest = {
                url = endpoint # "/transactions";
                method = #post;
                headers = headers;
                body = ?Text.encodeUtf8(requestBody);
                transform = null;
            };

            try {
                // Add cycles before making the call
                Cycles.add(25_000_000_000);  // adjust based on your tx size / expected cost

                let httpResponse = await ic.http_request(httpRequest);
                
                switch (httpResponse.status) {
                    case (200) {
                        // Parse response and extract transaction ID
                        let responseText = switch (Text.decodeUtf8(httpResponse.body)) {
                            case (?text) { text };
                            case null { return #err("Failed to decode response") };
                        };
                        
                        // Simplified response parsing - you should use proper JSON parsing
                        if (Text.contains(responseText, #text("transactionId"))) {
                            // Extract transaction ID from response
                            #ok("Transaction broadcast successfully") // Return actual TX ID
                        } else {
                            #err("Transaction rejected: " # responseText)
                        }
                    };
                    case (_) {
                        #err("HTTP error: " # Nat.toText(httpResponse.status))
                    };
                }
            } catch (e) {
                #err("Network error: " # Error.message(e))
            }
        };

        // Helper function to validate transaction before broadcasting
        public func validateTransaction(tx: KaspaTransaction): Bool {
            // Basic validation checks
            tx.inputs.size() > 0 and 
            tx.outputs.size() > 0 and
            tx.version > 0
        };

        // Get network info (useful for validation)
        public func getNetworkInfo(network: Network): async Result.Result<Text, Text> {
            let endpoint = getEndpoint(network) # "/info/blockdag";
            Debug.print(endpoint);
            
            let requestBody = "{"
                # "\"jsonrpc\":\"2.0\","
                # "\"method\":\"getInfo\","
                # "\"params\":{},"
                # "\"id\":\"" # Int.toText(Time.now()) # "\""
                # "}";

            let headers: [HttpHeader] = [
                { name = "Content-Type"; value = "application/json" },
                { name = "Accept"; value = "application/json" }
            ];

            let httpRequest: HttpRequest = {
                url = endpoint;
                max_response_bytes = ?1048576; // 1MB max response
                method = #get;
                headers = headers;
                body = ?Text.encodeUtf8(requestBody);
                transform = null;
            };

            try {
                // Add cycles for the HTTP request (25B cycles)
                Cycles.add(25_000_000_000);
                let httpResponse = await ic.http_request(httpRequest);
                
                switch (httpResponse.status) {
                    case (200) {
                        let responseText = switch (Text.decodeUtf8(httpResponse.body)) {
                            case (?text) { text };
                            case null { return #err("Failed to decode response") };
                        };
                        #ok(responseText)
                    };
                    case (_) {
                        #err("HTTP error: " # Nat.toText(httpResponse.status))
                    };
                }
            } catch (e) {
                #err("Network error: " # Error.message(e))
            }
        };
    }
}