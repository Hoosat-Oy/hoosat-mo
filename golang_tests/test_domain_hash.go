package main

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
)

func main() {
	// Calculate the ECDSA domain hash like HTND does
	domain := "TransactionSigningHashECDSA"
	domainHash := sha256.Sum256([]byte(domain))

	fmt.Printf("ECDSA Domain: %s\n", domain)
	fmt.Printf("ECDSA Domain Hash (hex): %s\n", hex.EncodeToString(domainHash[:]))
}
