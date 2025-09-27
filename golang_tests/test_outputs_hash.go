package main

import (
	"encoding/hex"
	"fmt"

	"lukechampine.com/blake3"
)

func main() {
	// Test the exact OutputsHash calculation from HTND
	domain := "TransactionSigningHash"
	var fixedSizeKey [32]byte
	copy(fixedSizeKey[:], domain)

	// Create the exact transaction outputs from the real transaction
	// Output 1: amount=15000, script="21020364e0d91f4557595ec5a1eda471b4c973cf01a1c2829ebc9b476aafc8ee23e3ab"
	// Output 2: amount=19999898000, script="210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab"

	// Manually construct the outputs preimage like HTND does
	var buf []byte

	// Output 1
	amount1 := uint64(15000)
	version1 := uint16(0)
	script1, _ := hex.DecodeString("21020364e0d91f4557595ec5a1eda471b4c973cf01a1c2829ebc9b476aafc8ee23e3ab")

	// Write amount (8 bytes little-endian)
	for i := 0; i < 8; i++ {
		buf = append(buf, byte(amount1>>(i*8)))
	}

	// Write version (2 bytes little-endian)
	for i := 0; i < 2; i++ {
		buf = append(buf, byte(version1>>(i*8)))
	}

	// Write script length (8 bytes little-endian)
	scriptLen1 := uint64(len(script1))
	for i := 0; i < 8; i++ {
		buf = append(buf, byte(scriptLen1>>(i*8)))
	}

	// Write script
	buf = append(buf, script1...)

	// Output 2
	amount2 := uint64(19999898000)
	version2 := uint16(0)
	script2, _ := hex.DecodeString("210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab")

	// Write amount (8 bytes little-endian)
	for i := 0; i < 8; i++ {
		buf = append(buf, byte(amount2>>(i*8)))
	}

	// Write version (2 bytes little-endian)
	for i := 0; i < 2; i++ {
		buf = append(buf, byte(version2>>(i*8)))
	}

	// Write script length (8 bytes little-endian)
	scriptLen2 := uint64(len(script2))
	for i := 0; i < 8; i++ {
		buf = append(buf, byte(scriptLen2>>(i*8)))
	}

	// Write script
	buf = append(buf, script2...)

	fmt.Printf("Constructed outputs preimage length: %d\n", len(buf))
	fmt.Printf("Constructed outputs preimage (hex): %s\n", hex.EncodeToString(buf))
	fmt.Printf("Motoko outputs preimage (hex): 983a0000000000000000230000000000000021020364e0d91f4557595ec5a1eda471b4c973cf01a1c2829ebc9b476aafc8ee23e3ab903916a80400000000002300000000000000210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab\n")

	if hex.EncodeToString(buf) == "983a0000000000000000230000000000000021020364e0d91f4557595ec5a1eda471b4c973cf01a1c2829ebc9b476aafc8ee23e3ab903916a80400000000002300000000000000210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab" {
		fmt.Println("✅ Outputs preimage matches!")
	} else {
		fmt.Println("❌ Outputs preimage doesn't match!")
	}

	// Calculate Blake3 keyed hash
	hasher := blake3.New(32, fixedSizeKey[:])
	hasher.Write(buf)
	keyedHash := hasher.Sum(nil)

	fmt.Printf("Go Blake3 keyed hash: %s\n", hex.EncodeToString(keyedHash))
	fmt.Printf("Motoko Blake3 keyed hash: 0840f689849e76906ebe47789410f437e6ded76970486c2d4cd64f42858effb0\n")
}
