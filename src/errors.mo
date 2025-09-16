import Debug "mo:base/Debug";

module {

    // Kaspa-specific error types
    public type KaspaError = {
        #InvalidAddress : { message: Text };
        #InvalidAmount : { message: Text; min: ?Nat64; max: ?Nat64 };
        #InvalidPublicKey : { message: Text; expected_length: Nat };
        #InvalidSignature : { message: Text };
        #InvalidTransaction : { message: Text };
        #InsufficientFunds : { required: Nat64; available: Nat64 };
        #NetworkError : { message: Text; status_code: ?Nat };
        #SerializationError : { message: Text };
        #CryptographicError : { message: Text };
        #ConfigurationError : { message: Text };
        #ValidationError : { message: Text };
        #InternalError : { message: Text };
    };

    // Convert KaspaError to human-readable text
    public func errorToText(error: KaspaError) : Text {
        switch (error) {
            case (#InvalidAddress(e)) { "Invalid address: " # e.message };
            case (#InvalidAmount(e)) {
                let range = switch (e.min, e.max) {
                    case (?min, ?max) { " (valid range: " # debug_show(min) # " - " # debug_show(max) # ")" };
                    case (?min, null) { " (minimum: " # debug_show(min) # ")" };
                    case (null, ?max) { " (maximum: " # debug_show(max) # ")" };
                    case (null, null) { "" };
                };
                "Invalid amount: " # e.message # range
            };
            case (#InvalidPublicKey(e)) { "Invalid public key: " # e.message # " (expected length: " # debug_show(e.expected_length) # ")" };
            case (#InvalidSignature(e)) { "Invalid signature: " # e.message };
            case (#InvalidTransaction(e)) { "Invalid transaction: " # e.message };
            case (#InsufficientFunds(e)) { "Insufficient funds: required " # debug_show(e.required) # ", available " # debug_show(e.available) };
            case (#NetworkError(e)) {
                let status = switch (e.status_code) {
                    case (?code) { " (HTTP " # debug_show(code) # ")" };
                    case (null) { "" };
                };
                "Network error: " # e.message # status
            };
            case (#SerializationError(e)) { "Serialization error: " # e.message };
            case (#CryptographicError(e)) { "Cryptographic error: " # e.message };
            case (#ConfigurationError(e)) { "Configuration error: " # e.message };
            case (#ValidationError(e)) { "Validation error: " # e.message };
            case (#InternalError(e)) { "Internal error: " # e.message };
        };
    };

    // Helper functions for creating common errors
    public func invalidAddress(message: Text) : KaspaError {
        #InvalidAddress({ message })
    };

    public func invalidAmount(message: Text, min: ?Nat64, max: ?Nat64) : KaspaError {
        #InvalidAmount({ message; min; max })
    };

    public func insufficientFunds(required: Nat64, available: Nat64) : KaspaError {
        #InsufficientFunds({ required; available })
    };

    public func networkError(message: Text, status_code: ?Nat) : KaspaError {
        #NetworkError({ message; status_code })
    };

    public func cryptographicError(message: Text) : KaspaError {
        #CryptographicError({ message })
    };

    public func validationError(message: Text) : KaspaError {
        #ValidationError({ message })
    };

    public func internalError(message: Text) : KaspaError {
        #InternalError({ message })
    };

    public func invalidPublicKey(message: Text, expected_length: Nat) : KaspaError {
        #InvalidPublicKey({ message; expected_length })
    };
}