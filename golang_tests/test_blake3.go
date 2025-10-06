package main

import (
	"encoding/hex"
	"fmt"
	"log"

	"lukechampine.com/blake3"
)

func main() {
	// Test the same data that Motoko is hashing
	// Motoko outputs preimage: e8030000000000000000230000000000000021020364e0d91f4557595ec5a1eda471b4c973cf01a1c2829ebc9b476aafc8ee23e3ab389b16a80400000000002300000000000000210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab

	data, err := hex.DecodeString("e8030000000000000000230000000000000021020364e0d91f4557595ec5a1eda471b4c973cf01a1c2829ebc9b476aafc8ee23e3ab389b16a80400000000002300000000000000210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab")
	if err != nil {
		log.Fatalf("Failed to decode hex: %v", err)
	}

	// Create the same key as Motoko: "TransactionSigningHash" padded to 32 bytes
	key := []byte("TransactionSigningHash")
	var fixedKey [32]byte
	copy(fixedKey[:], key)

	// Calculate Blake3 keyed hash using the same method as HTND
	hasher := blake3.New(32, fixedKey[:])
	hasher.Write(data)
	keyedHash := hasher.Sum(nil)

	// Also calculate regular Blake3 for comparison
	regularHash := blake3.Sum256(data)

	fmt.Printf("Data length: %d\n", len(data))
	fmt.Printf("Data (hex): %s\n", hex.EncodeToString(data))
	fmt.Printf("Key (hex): %s\n", hex.EncodeToString(fixedKey[:]))
	fmt.Printf("Blake3 hash (no key): %s\n", hex.EncodeToString(regularHash[:]))
	fmt.Printf("Blake3 keyed hash: %s\n", hex.EncodeToString(keyedHash))
	fmt.Printf("Expected Motoko result: 02d5f30201bde36ffe975a2f6a59908cef79c45d0b8cc0d905de5db6ccb482ea\n")
}
