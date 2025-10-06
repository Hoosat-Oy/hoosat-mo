import Debug "mo:base/Debug";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";

import Validation "../src/validation";
import Errors "../src/errors";

persistent actor {

    private func textEq(a: Text, b: Text) : Bool { a == b };
    private func textToText(t: Text) : Text { t };

    private func assertEqual<T>(
        actual: T,
        expected: T,
        message: Text,
        eq: (T, T) -> Bool,
        toText: T -> Text
    ) : Bool {
        if (eq(actual, expected)) {
            Debug.print("✅ PASS: " # message);
            true
        } else {
            Debug.print("❌ FAIL: " # message # " (expected: " # toText(expected) # ", actual: " # toText(actual) # ")");
            false
        }
    };

    private func assertOk<T>(result: Result.Result<T, Errors.HoosatError>, message: Text) : Bool {
        switch (result) {
            case (#ok(_)) {
                Debug.print("✅ PASS: " # message);
                true
            };
            case (#err(error)) {
                Debug.print("❌ FAIL: " # message # " (error: " # Errors.errorToText(error) # ")");
                false
            };
        }
    };

    private func assertErr<T>(result: Result.Result<T, Errors.HoosatError>, message: Text) : Bool {
        switch (result) {
            case (#ok(_)) {
                Debug.print("❌ FAIL: " # message # " (expected error but got ok)");
                false
            };
            case (#err(_)) {
                Debug.print("✅ PASS: " # message);
                true
            };
        }
    };

    public func runTests() : async Text {
        Debug.print("🧪 Running Validation Tests...");

        var passed : Nat = 0;
        var total : Nat = 0;

        // Test valid address (using a known valid address from the working tests)
        total += 1;
        if (assertOk(
            Validation.validateAddress("Hoosat:qqs7krzzwqfgk9kf830smtzg64s9rf3r0khfj76cjynf2pfgrr35saatu88xq"),
            "Valid Hoosat address should pass"
        )) {
            passed += 1;
        };

        // Test invalid address
        total += 1;
        if (assertErr(
            Validation.validateAddress(""),
            "Empty address should fail"
        )) {
            passed += 1;
        };

        // Test invalid prefix
        total += 1;
        if (assertErr(
            Validation.validateAddress("bitcoin:qypqxpq9qcrsszg2pvxq6rs0zqg3yyc5z58d6rjcm0ts637kgsxhx2mxrrd"),
            "Invalid prefix should fail"
        )) {
            passed += 1;
        };

        // Test valid amount
        total += 1;
        if (assertOk(
            Validation.validateAmount(100_000, false),
            "Valid amount should pass"
        )) {
            passed += 1;
        };

        // Test zero amount
        total += 1;
        if (assertErr(
            Validation.validateAmount(0, false),
            "Zero amount should fail"
        )) {
            passed += 1;
        };

        // Test dust amount
        total += 1;
        if (assertErr(
            Validation.validateAmount(500, true),
            "Amount below dust threshold should fail with dust check"
        )) {
            passed += 1;
        };

        // Test valid fee
        total += 1;
        if (assertOk(
            Validation.validateFee(10_000),
            "Valid fee should pass"
        )) {
            passed += 1;
        };

        // Test invalid fee
        total += 1;
        if (assertErr(
            Validation.validateFee(500),
            "Fee below minimum should fail"
        )) {
            passed += 1;
        };

        // Test valid hex
        total += 1;
        if (assertOk(
            Validation.validateHexString("deadbeef", ?4),
            "Valid hex string should pass"
        )) {
            passed += 1;
        };

        // Test invalid hex
        total += 1;
        if (assertErr(
            Validation.validateHexString("", null),
            "Empty hex string should fail"
        )) {
            passed += 1;
        };

        // Test valid derivation path
        total += 1;
        if (assertOk(
            Validation.validateDerivationPath("44'/111111'/0'/0/0"),
            "Valid BIP44 path should pass"
        )) {
            passed += 1;
        };

        // Test invalid derivation path
        total += 1;
        if (assertErr(
            Validation.validateDerivationPath("44'/111111'/0'/0/a"),
            "Path with non-numeric component should fail"
        )) {
            passed += 1;
        };

        let summary = "Test Summary: " # Nat.toText(passed) # "/" # Nat.toText(total) # " tests passed";
        Debug.print("🏁 " # summary);
        summary
    };
}