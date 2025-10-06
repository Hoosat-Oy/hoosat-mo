package main

import (
	"encoding/hex"
	"fmt"

	"lukechampine.com/blake3"
)

func main() {
	// Test the exact same data as Motoko
	domain := "TransactionSigningHash"

	// Create the key exactly like HTND does
	var fixedSizeKey [32]byte
	copy(fixedSizeKey[:], domain)

	fmt.Printf("Domain: %s\n", domain)
	fmt.Printf("Domain length: %d\n", len(domain))
	fmt.Printf("Fixed key (hex): %s\n", hex.EncodeToString(fixedSizeKey[:]))

	// Test with the exact Outputs preimage from Motoko logs
	outputsPreimage := "983a0000000000000000230000000000000021020364e0d91f4557595ec5a1eda471b4c973cf01a1c2829ebc9b476aafc8ee23e3ab903916a80400000000002300000000000000210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab"
	outputsData, err := hex.DecodeString(outputsPreimage)
	if err != nil {
		fmt.Printf("Error decoding hex: %v\n", err)
		return
	}

	fmt.Printf("Outputs preimage length: %d\n", len(outputsData))
	fmt.Printf("Outputs preimage (hex): %s\n", hex.EncodeToString(outputsData))

	// Calculate Blake3 keyed hash exactly like HTND
	hasher := blake3.New(32, fixedSizeKey[:])
	hasher.Write(outputsData)
	keyedHash := hasher.Sum(nil)

	fmt.Printf("Go Blake3 keyed hash: %s\n", hex.EncodeToString(keyedHash))
	fmt.Printf("Motoko Blake3 keyed hash: 0840f689849e76906ebe47789410f437e6ded76970486c2d4cd64f42858effb0\n")

	if hex.EncodeToString(keyedHash) == "0840f689849e76906ebe47789410f437e6ded76970486c2d4cd64f42858effb0" {
		fmt.Println("✅ MATCH! Blake3 keyed hash is correct")
	} else {
		fmt.Println("❌ MISMATCH! Blake3 keyed hash is incorrect")
	}

	// Also test the PreviousOutputsHash
	prevOutputsData := "524b95d1e50111beeb7ce9020c0cb8a4042459a9acc7c172029edcbb3d37d3a901000000"
	prevOutputsBytes, err := hex.DecodeString(prevOutputsData)
	if err != nil {
		fmt.Printf("Error decoding prev outputs hex: %v\n", err)
		return
	}

	hasher2 := blake3.New(32, fixedSizeKey[:])
	hasher2.Write(prevOutputsBytes)
	prevHash := hasher2.Sum(nil)

	fmt.Printf("PreviousOutputs data: %s\n", prevOutputsData)
	fmt.Printf("Go PreviousOutputsHash: %s\n", hex.EncodeToString(prevHash))
	fmt.Printf("Motoko PreviousOutputsHash: 4fe07f0779e0dd2f2b90086be638a13322f7f481c5bbabf2cc74b9a0645ed013\n")
}
