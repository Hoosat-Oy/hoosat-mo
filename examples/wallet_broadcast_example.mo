// Example demonstrating the new broadcasting functionality
import Wallet "../src/wallet";
import Errors "../src/errors";
import Result "mo:base/Result";

// Example usage of the new broadcasting features
persistent actor WalletBroadcastExample {

    // Initialize a mainnet wallet
    transient let wallet = Wallet.createMainnetWallet("dfx_test_key");

    // Example: Build and broadcast a transaction in one step
    public func sendKaspa(
        from_address: Text,
        to_address: Text,
        amount: Nat64
    ) : async Result.Result<Wallet.TransactionResult, Errors.KaspaError> {
        await wallet.sendTransaction(
            from_address,
            to_address,
            amount,
            null, // Use default fee
            null  // Use default derivation path
        )
    };

    // Example: Build transaction without broadcasting (for manual submission)
    public func buildTransaction(
        from_address: Text,
        to_address: Text,
        amount: Nat64
    ) : async Result.Result<{serialized_tx: Text; fee_paid: Nat64}, Errors.KaspaError> {
        await wallet.buildTransaction(
            from_address,
            to_address,
            amount,
            null, // Use default fee
            null  // Use default derivation path
        )
    };

    // Example: Broadcast a pre-built transaction
    public func broadcastTransaction(serialized_tx: Text) : async Result.Result<Text, Errors.KaspaError> {
        await wallet.broadcastSerializedTransaction(serialized_tx)
    };

    // Example: Check transaction status
    public func checkTransactionStatus(tx_id: Text) : async Result.Result<{status: Text; confirmations: ?Nat}, Errors.KaspaError> {
        await wallet.getTransactionStatus(tx_id)
    };

    // Example: Get wallet balance
    public func getBalance(address: Text) : async Result.Result<Wallet.Balance, Errors.KaspaError> {
        await wallet.getBalance(address)
    };

    // Example: Generate a new address
    public func generateAddress() : async Result.Result<Wallet.AddressInfo, Errors.KaspaError> {
        await wallet.generateAddress(null, null) // Use defaults
    };
}