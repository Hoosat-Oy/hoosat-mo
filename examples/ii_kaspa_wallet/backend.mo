// Internet Identity + Kaspa Wallet Example
// Demonstrates how to integrate Internet Identity authentication with Kaspa wallet functionality

import Map "mo:base/HashMap";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";

import SHA256 "mo:sha2/Sha256";

import Wallet "../../src/wallet";
import Errors "../../src/errors";

persistent actor II_KaspaWallet {

    // User session type
    public type UserSession = {
        principal: Principal;
        created_at: Int;
        last_active: Int;
        wallet_instance: Wallet.Wallet;
    };

    // User wallet data that persists across upgrades
    public type UserWalletData = {
        principal: Principal;
        created_at: Int;
        addresses_generated: Nat;
        total_transactions: Nat;
    };

    // Stable storage for user data
    var user_data_stable : [(Principal, UserWalletData)] = [];

    // Runtime session storage (cleared on upgrade)
    transient var user_sessions = Map.HashMap<Principal, UserSession>(10, Principal.equal, Principal.hash);

    // Session timeout (24 hours)
    let SESSION_TIMEOUT: Int = 24 * 60 * 60 * 1_000_000_000; // nanoseconds

    // Restore user data from stable storage
    system func preupgrade() {
        user_data_stable := Iter.toArray(user_data_stable.vals());
    };

    system func postupgrade() {
        user_data_stable := [];
        // Sessions are intentionally not restored - users need to re-authenticate after upgrades
    };

    // Get caller's identity
    private func get_caller() : Principal {
        let caller = Principal.fromActor(II_KaspaWallet);
        caller
    };

    // Convert principal to secure derivation path using SHA256
    private func principalToDerivationPath(principal: Principal) : Text {
        // Get principal as bytes
        let principalBytes = Principal.toBlob(principal);

        // Hash the principal to get a deterministic but collision-resistant path
        let hash = SHA256.fromBlob(#sha256, principalBytes);

        // Convert first 4 bytes of hash to a 32-bit number
        // This gives us 2^32 possible values (over 4 billion)
        let hashBytes = Blob.toArray(hash);
        let pathBytes = Array.subArray(hashBytes, 0, 4);

        // Convert 4 bytes to Nat32 (big-endian)
        var value : Nat32 = 0;
        for (i in Iter.range(0, 3)) {
            value := value * 256 + Nat32.fromNat(Nat8.toNat(pathBytes[i]));
        };

        // Convert to string - purely numeric, always valid for derivation paths
        Nat32.toText(value)
    };

    // Validate session and return user session
    private func validate_session(caller: Principal) : ?UserSession {
        switch (user_sessions.get(caller)) {
            case (null) { null };
            case (?session) {
                let now = Time.now();
                if (now - session.last_active > SESSION_TIMEOUT) {
                    user_sessions.delete(caller);
                    null
                } else {
                    // Update last active time
                    let updated_session = {
                        session with last_active = now
                    };
                    user_sessions.put(caller, updated_session);
                    ?updated_session
                }
            };
        }
    };

    // Initialize or get existing user session
    private func get_or_create_session(caller: Principal) : UserSession {
        switch (user_sessions.get(caller)) {
            case (?session) { session };
            case (null) {
                let now = Time.now();

                // Create wallet instance with user-specific key derivation
                let user_key_name = "dfx_test_key"; // In production, could be user-specific
                let wallet = Wallet.createMainnetWallet(user_key_name);

                let new_session: UserSession = {
                    principal = caller;
                    created_at = now;
                    last_active = now;
                    wallet_instance = wallet;
                };

                user_sessions.put(caller, new_session);
                new_session
            };
        }
    };

    // Public API Functions

    // Login/Initialize user session
    public shared(msg) func login() : async Result.Result<{principal: Text; session_created: Bool}, Text> {
        let caller = msg.caller;

        // Reject anonymous calls
        if (Principal.isAnonymous(caller)) {
            return #err("Anonymous access not allowed. Please authenticate with Internet Identity.");
        };

        let session = get_or_create_session(caller);
        let is_new_session = switch (user_sessions.get(caller)) {
            case (null) { true };
            case (?_) { false };
        };

        #ok({
            principal = Principal.toText(caller);
            session_created = is_new_session;
        })
    };

    // Logout and clear session
    public shared(msg) func logout() : async Result.Result<(), Text> {
        let caller = msg.caller;
        user_sessions.delete(caller);
        #ok(())
    };

    // Check if user is authenticated
    public shared(msg) func whoami() : async Result.Result<{principal: Text; session_active: Bool}, Text> {
        let caller = msg.caller;

        if (Principal.isAnonymous(caller)) {
            return #ok({
                principal = "anonymous";
                session_active = false;
            });
        };

        let session_active = switch (validate_session(caller)) {
            case (null) { false };
            case (?_) { true };
        };

        #ok({
            principal = Principal.toText(caller);
            session_active = session_active;
        })
    };

    // Generate a new Kaspa address for the authenticated user
    public shared(msg) func generateAddress() : async Result.Result<Wallet.AddressInfo, Errors.KaspaError> {
        let caller = msg.caller;

        switch (validate_session(caller)) {
            case (null) {
                return #err(#ValidationError({message = "Not authenticated. Please login first."}));
            };
            case (?session) {
                // Use user's principal as part of derivation path for unique addresses
                let user_path = principalToDerivationPath(caller);
                await session.wallet_instance.generateAddress(?user_path, null)
            };
        }
    };

    // Get balance for user's address
    public shared(msg) func getBalance(address: Text) : async Result.Result<Wallet.Balance, Errors.KaspaError> {
        let caller = msg.caller;

        switch (validate_session(caller)) {
            case (null) {
                return #err(#ValidationError({message = "Not authenticated. Please login first."}));
            };
            case (?session) {
                await session.wallet_instance.getBalance(address)
            };
        }
    };

    // Send Kaspa transaction for authenticated user
    public shared(msg) func sendTransaction(
        from_address: Text,
        to_address: Text,
        amount: Nat64
    ) : async Result.Result<Wallet.TransactionResult, Errors.KaspaError> {
        let caller = msg.caller;

        switch (validate_session(caller)) {
            case (null) {
                return #err(#ValidationError({message = "Not authenticated. Please login first."}));
            };
            case (?session) {
                // Use user's principal as derivation path for signing
                let user_path = principalToDerivationPath(caller);
                await session.wallet_instance.sendTransaction(
                    from_address,
                    to_address,
                    amount,
                    null, // Use default fee
                    ?user_path
                )
            };
        }
    };

    // Build transaction without broadcasting
    public shared(msg) func buildTransaction(
        from_address: Text,
        to_address: Text,
        amount: Nat64
    ) : async Result.Result<{serialized_tx: Text; fee_paid: Nat64}, Errors.KaspaError> {
        let caller = msg.caller;

        switch (validate_session(caller)) {
            case (null) {
                return #err(#ValidationError({message = "Not authenticated. Please login first."}));
            };
            case (?session) {
                let user_path = principalToDerivationPath(caller);
                await session.wallet_instance.buildTransaction(
                    from_address,
                    to_address,
                    amount,
                    null, // Use default fee
                    ?user_path
                )
            };
        }
    };

    // Broadcast a pre-built transaction
    public shared(msg) func broadcastTransaction(serialized_tx: Text) : async Result.Result<Text, Errors.KaspaError> {
        let caller = msg.caller;

        switch (validate_session(caller)) {
            case (null) {
                return #err(#ValidationError({message = "Not authenticated. Please login first."}));
            };
            case (?session) {
                await session.wallet_instance.broadcastSerializedTransaction(serialized_tx)
            };
        }
    };

    // Check transaction status
    public shared(msg) func getTransactionStatus(tx_id: Text) : async Result.Result<{status: Text; confirmations: ?Nat}, Errors.KaspaError> {
        let caller = msg.caller;

        switch (validate_session(caller)) {
            case (null) {
                return #err(#ValidationError({message = "Not authenticated. Please login first."}));
            };
            case (?session) {
                await session.wallet_instance.getTransactionStatus(tx_id)
            };
        }
    };

    // Get user statistics (public info)
    public shared(msg) func getUserStats() : async Result.Result<{
        principal: Text;
        active_sessions: Nat;
        session_created_at: ?Int;
    }, Text> {
        let caller = msg.caller;

        if (Principal.isAnonymous(caller)) {
            return #err("Not authenticated");
        };

        switch (validate_session(caller)) {
            case (null) {
                #ok({
                    principal = Principal.toText(caller);
                    active_sessions = 0;
                    session_created_at = null;
                })
            };
            case (?session) {
                #ok({
                    principal = Principal.toText(caller);
                    active_sessions = 1;
                    session_created_at = ?session.created_at;
                })
            };
        }
    };

    // Admin function to get system stats (only for canister controller)
    public shared(msg) func getSystemStats() : async Result.Result<{
        total_active_sessions: Nat;
        total_registered_users: Nat;
    }, Text> {
        // In a real implementation, you'd check if caller is controller
        // For demo purposes, returning basic stats

        #ok({
            total_active_sessions = user_sessions.size();
            total_registered_users = user_data_stable.size();
        })
    };
}