package main

import (
	"encoding/hex"
	"fmt"

	"lukechampine.com/blake3"
)

func main() {
	// Test different key creation approaches
	domain := "TransactionSigningHash"
	
	// Approach 1: Copy domain string into 32-byte array (like our Motoko implementation)
	var key1 [32]byte
	copy(key1[:], []byte(domain))
	fmt.Printf("Approach 1 - Copy domain into 32-byte array:\n")
	fmt.Printf("Key (hex): %s\n", hex.EncodeToString(key1[:]))
	
	// Approach 2: Use domain string directly as key (if it's exactly 32 bytes)
	if len(domain) == 32 {
		var key2 [32]byte
		copy(key2[:], []byte(domain))
		fmt.Printf("Approach 2 - Use domain directly (32 bytes):\n")
		fmt.Printf("Key (hex): %s\n", hex.EncodeToString(key2[:]))
	} else {
		fmt.Printf("Approach 2 - Domain is %d bytes, not 32\n", len(domain))
	}
	
	// Approach 3: Hash the domain string first, then use as key
	domainHash := blake3.Sum256([]byte(domain))
	fmt.Printf("Approach 3 - Hash domain first:\n")
	fmt.Printf("Domain hash (hex): %s\n", hex.EncodeToString(domainHash[:]))
	
	// Test with sample data
	testData := []byte("test data for blake3 keyed hash")
	
	// Test with approach 1
	hasher1 := blake3.New(32, key1[:])
	hasher1.Write(testData)
	result1 := hasher1.Sum(nil)
	fmt.Printf("Blake3 keyed hash with approach 1: %s\n", hex.EncodeToString(result1))
	
	// Test with approach 3
	hasher3 := blake3.New(32, domainHash[:])
	hasher3.Write(testData)
	result3 := hasher3.Sum(nil)
	fmt.Printf("Blake3 keyed hash with approach 3: %s\n", hex.EncodeToString(result3))
}
