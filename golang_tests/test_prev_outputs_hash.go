package main

import (
	"encoding/hex"
	"fmt"

	"lukechampine.com/blake3"
)

func main() {
	// Test the PreviousOutputsHash calculation
	domain := "TransactionSigningHash"
	var fixedSizeKey [32]byte
	copy(fixedSizeKey[:], domain)

	// The PreviousOutputsHash should hash the single input's outpoint
	// Transaction ID: 524b95d1e50111beeb7ce9020c0cb8a4042459a9acc7c172029edcbb3d37d3a9
	// Index: 1

	// Create the exact data that should be hashed
	var buf []byte

	// Transaction ID (32 bytes)
	txID, _ := hex.DecodeString("524b95d1e50111beeb7ce9020c0cb8a4042459a9acc7c172029edcbb3d37d3a9")
	buf = append(buf, txID...)

	// Index (4 bytes little-endian)
	index := uint32(1)
	for i := 0; i < 4; i++ {
		buf = append(buf, byte(index>>(i*8)))
	}

	fmt.Printf("PreviousOutputs data length: %d\n", len(buf))
	fmt.Printf("PreviousOutputs data (hex): %s\n", hex.EncodeToString(buf))

	// Calculate Blake3 keyed hash
	hasher := blake3.New(32, fixedSizeKey[:])
	hasher.Write(buf)
	keyedHash := hasher.Sum(nil)

	fmt.Printf("Go PreviousOutputsHash: %s\n", hex.EncodeToString(keyedHash))
	fmt.Printf("Motoko PreviousOutputsHash: e328c4c9eaf1481381c161672c65f35e1201ab69d0b8084e8c2afc0e681988ec\n")

	if hex.EncodeToString(keyedHash) == "e328c4c9eaf1481381c161672c65f35e1201ab69d0b8084e8c2afc0e681988ec" {
		fmt.Println("✅ MATCH! PreviousOutputsHash is correct")
	} else {
		fmt.Println("❌ MISMATCH! PreviousOutputsHash is incorrect")
	}
}
