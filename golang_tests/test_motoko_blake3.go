package main

import (
	"encoding/hex"
	"fmt"

	"lukechampine.com/blake3"
)

func main() {
	// Test our custom Blake3 keyed hash implementation
	domain := "TransactionSigningHash"
	var fixedSizeKey [32]byte
	copy(fixedSizeKey[:], domain)

	// Test data from Motoko logs
	testData := "983a0000000000000000230000000000000021020364e0d91f4557595ec5a1eda471b4c973cf01a1c2829ebc9b476aafc8ee23e3ab903916a80400000000002300000000000000210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab"
	data, _ := hex.DecodeString(testData)

	// Go Blake3 keyed hash (correct)
	hasher := blake3.New(32, fixedSizeKey[:])
	hasher.Write(data)
	goResult := hasher.Sum(nil)

	// Our custom implementation (HMAC-like)
	// Step 1: Inner hash: Blake3(key + data)
	innerData := make([]byte, len(fixedSizeKey)+len(data))
	copy(innerData, fixedSizeKey[:])
	copy(innerData[len(fixedSizeKey):], data)
	innerHash := blake3.Sum256(innerData)

	// Step 2: Outer hash: Blake3(key + inner_hash)
	outerData := make([]byte, len(fixedSizeKey)+len(innerHash))
	copy(outerData, fixedSizeKey[:])
	copy(outerData[len(fixedSizeKey):], innerHash[:])
	customResult := blake3.Sum256(outerData)

	fmt.Printf("Go Blake3 keyed hash: %s\n", hex.EncodeToString(goResult))
	fmt.Printf("Custom HMAC-like hash: %s\n", hex.EncodeToString(customResult[:]))

	if hex.EncodeToString(goResult) == hex.EncodeToString(customResult[:]) {
		fmt.Println("✅ MATCH! Custom implementation works")
	} else {
		fmt.Println("❌ MISMATCH! Custom implementation needs adjustment")
	}
}
