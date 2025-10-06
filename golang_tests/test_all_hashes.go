package main

import (
	"encoding/hex"
	"fmt"

	"lukechampine.com/blake3"
)

func main() {
	domain := "TransactionSigningHash"
	var fixedSizeKey [32]byte
	copy(fixedSizeKey[:], domain)

	// Test SequencesHash (should be zero for SigHashAll with one input)
	var seqBuf []byte
	sequence := uint64(0)
	for i := 0; i < 8; i++ {
		seqBuf = append(seqBuf, byte(sequence>>(i*8)))
	}

	hasher1 := blake3.New(32, fixedSizeKey[:])
	hasher1.Write(seqBuf)
	seqHash := hasher1.Sum(nil)

	fmt.Printf("SequencesHash data: %s\n", hex.EncodeToString(seqBuf))
	fmt.Printf("Go SequencesHash: %s\n", hex.EncodeToString(seqHash))

	// Test SigOpCountsHash
	var sigOpBuf []byte
	sigOpCount := uint8(1)
	sigOpBuf = append(sigOpBuf, sigOpCount)

	hasher2 := blake3.New(32, fixedSizeKey[:])
	hasher2.Write(sigOpBuf)
	sigOpHash := hasher2.Sum(nil)

	fmt.Printf("SigOpCountsHash data: %s\n", hex.EncodeToString(sigOpBuf))
	fmt.Printf("Go SigOpCountsHash: %s\n", hex.EncodeToString(sigOpHash))
}
