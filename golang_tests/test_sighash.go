package main

import (
	"bytes"
	"encoding/hex"
	"fmt"
	"log"

	"github.com/Hoosat-Oy/HTND/domain/consensus/model/externalapi"
	"github.com/Hoosat-Oy/HTND/domain/consensus/utils/consensushashing"
	"github.com/Hoosat-Oy/HTND/domain/consensus/utils/hashes"
	"github.com/Hoosat-Oy/HTND/domain/consensus/utils/serialization"
	"github.com/Hoosat-Oy/HTND/domain/consensus/utils/subnetworks"
	"github.com/Hoosat-Oy/HTND/domain/consensus/utils/utxo"
)

func main() {
	// Test data from the Motoko logs
	// UTXO: txid=999f36d9e74b646db3069ad9fab54edb1464445ce083f4e468b7c9f23c7b723f, index=1, amount=19999934000
	// Script: 210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab

	// Create transaction ID
	txIDBytes := hexToBytes("999f36d9e74b646db3069ad9fab54edb1464445ce083f4e468b7c9f23c7b723f")
	var txIDArray [32]byte
	copy(txIDArray[:], txIDBytes)
	txID := externalapi.NewDomainTransactionIDFromByteArray(&txIDArray)

	// Create the transaction
	tx := &externalapi.DomainTransaction{
		Version: 0,
		Inputs: []*externalapi.DomainTransactionInput{
			{
				PreviousOutpoint: externalapi.DomainOutpoint{
					TransactionID: *txID,
					Index:         1,
				},
				SignatureScript: []byte{},
				Sequence:        0,
				SigOpCount:      1,
			},
		},
		Outputs: []*externalapi.DomainTransactionOutput{
			{
				Value: 1000,
				ScriptPublicKey: &externalapi.ScriptPublicKey{
					Script:  hexToBytes("21020364e0d91f4557595ec5a1eda471b4c973cf01a1c2829ebc9b476aafc8ee23e3ab"),
					Version: 0,
				},
			},
			{
				Value: 19999923000,
				ScriptPublicKey: &externalapi.ScriptPublicKey{
					Script:  hexToBytes("210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab"),
					Version: 0,
				},
			},
		},
		LockTime:     0,
		SubnetworkID: subnetworks.SubnetworkIDNative,
		Gas:          0,
		Payload:      nil,
	}

	// Set up the UTXO entry for the input
	utxoScript := &externalapi.ScriptPublicKey{
		Script:  hexToBytes("210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab"),
		Version: 0,
	}

	tx.Inputs[0].UTXOEntry = utxo.NewUTXOEntry(19999934000, utxoScript, false, 0)

	// Calculate signature hash using HTND
	reusedValues := &consensushashing.SighashReusedValues{}
	hash, err := consensushashing.CalculateSignatureHashECDSA(tx, 0, consensushashing.SigHashAll, reusedValues)
	if err != nil {
		log.Fatalf("Failed to calculate signature hash: %v", err)
	}

	fmt.Printf("Go HTND ECDSA Sighash: %s\n", hash.String())

	// Also calculate Schnorr for comparison
	reusedValues2 := &consensushashing.SighashReusedValues{}
	hash2, err := consensushashing.CalculateSignatureHashSchnorr(tx, 0, consensushashing.SigHashAll, reusedValues2)
	if err != nil {
		log.Fatalf("Failed to calculate Schnorr signature hash: %v", err)
	}

	fmt.Printf("Go HTND Schnorr Sighash: %s\n", hash2.String())

	// Manual preimage construction to match Motoko debug output
	fmt.Println("\n=== Manual Preimage Construction ===")

	// Create a buffer to manually construct the preimage
	var buf bytes.Buffer

	// Version (uint16)
	serialization.WriteElement(&buf, tx.Version)
	fmt.Printf("Version bytes: %s\n", hex.EncodeToString(buf.Bytes()[buf.Len()-2:]))

	// PreviousOutputsHash (recompute to get the value)
	prevHashWriter := hashes.NewTransactionSigningHashWriter()
	for _, txIn := range tx.Inputs {
		serialization.WriteElement(prevHashWriter, txIn.PreviousOutpoint.TransactionID)
		serialization.WriteElement(prevHashWriter, txIn.PreviousOutpoint.Index)
	}
	prevHash := prevHashWriter.Finalize()
	serialization.WriteElement(&buf, prevHash)
	fmt.Printf("PreviousOutputsHash: %s\n", prevHash.String())

	// SequencesHash (should be zero for SigHashAll with one input)
	seqHashWriter := hashes.NewTransactionSigningHashWriter()
	for _, txIn := range tx.Inputs {
		serialization.WriteElement(seqHashWriter, txIn.Sequence)
	}
	seqHash := seqHashWriter.Finalize()
	serialization.WriteElement(&buf, seqHash)
	fmt.Printf("SequencesHash: %s\n", seqHash.String())

	// SigOpCountsHash
	sigOpHashWriter := hashes.NewTransactionSigningHashWriter()
	for _, txIn := range tx.Inputs {
		serialization.WriteElement(sigOpHashWriter, txIn.SigOpCount)
	}
	sigOpHash := sigOpHashWriter.Finalize()
	serialization.WriteElement(&buf, sigOpHash)
	fmt.Printf("SigOpCountsHash: %s\n", sigOpHash.String())

	// Outpoint (TransactionID + Index)
	serialization.WriteElement(&buf, tx.Inputs[0].PreviousOutpoint.TransactionID)
	serialization.WriteElement(&buf, tx.Inputs[0].PreviousOutpoint.Index)
	fmt.Printf("Transaction ID: %s\n", tx.Inputs[0].PreviousOutpoint.TransactionID.String())
	fmt.Printf("Index: %d\n", tx.Inputs[0].PreviousOutpoint.Index)

	// Script details (version + script)
	serialization.WriteElement(&buf, tx.Inputs[0].UTXOEntry.ScriptPublicKey().Version)
	serialization.WriteElement(&buf, tx.Inputs[0].UTXOEntry.ScriptPublicKey().Script)
	fmt.Printf("Script version: %d\n", tx.Inputs[0].UTXOEntry.ScriptPublicKey().Version)
	fmt.Printf("Script: %s\n", hex.EncodeToString(tx.Inputs[0].UTXOEntry.ScriptPublicKey().Script))

	// Amount
	serialization.WriteElement(&buf, tx.Inputs[0].UTXOEntry.Amount())
	fmt.Printf("Amount: %d\n", tx.Inputs[0].UTXOEntry.Amount())

	// Sequence
	serialization.WriteElement(&buf, tx.Inputs[0].Sequence)
	fmt.Printf("Sequence: %d\n", tx.Inputs[0].Sequence)

	// SigOpCount
	serialization.WriteElement(&buf, tx.Inputs[0].SigOpCount)
	fmt.Printf("SigOpCount: %d\n", tx.Inputs[0].SigOpCount)

	// OutputsHash
	outHashWriter := hashes.NewTransactionSigningHashWriter()
	for i, txOut := range tx.Outputs {
		fmt.Printf("Output %d - Value: %d\n", i, txOut.Value)
		fmt.Printf("Output %d - Script Version: %d\n", i, txOut.ScriptPublicKey.Version)
		fmt.Printf("Output %d - Script: %s\n", i, hex.EncodeToString(txOut.ScriptPublicKey.Script))
		serialization.WriteElement(outHashWriter, txOut.Value)
		serialization.WriteElement(outHashWriter, txOut.ScriptPublicKey.Version)
		serialization.WriteElement(outHashWriter, txOut.ScriptPublicKey.Script)
	}
	outHash := outHashWriter.Finalize()
	serialization.WriteElement(&buf, outHash)
	fmt.Printf("OutputsHash: %s\n", outHash.String())

	// LockTime
	serialization.WriteElement(&buf, tx.LockTime)
	fmt.Printf("LockTime: %d\n", tx.LockTime)

	// SubnetworkID
	serialization.WriteElement(&buf, tx.SubnetworkID)
	fmt.Printf("SubnetworkID: %s\n", hex.EncodeToString(tx.SubnetworkID[:]))

	// Gas
	serialization.WriteElement(&buf, tx.Gas)
	fmt.Printf("Gas: %d\n", tx.Gas)

	// PayloadHash (should be zero for native subnetwork)
	payloadHash := externalapi.NewZeroHash()
	serialization.WriteElement(&buf, payloadHash)
	fmt.Printf("PayloadHash: %s\n", payloadHash.String())

	// SighashType
	serialization.WriteElement(&buf, uint8(consensushashing.SigHashAll))
	fmt.Printf("SighashType: %d\n", uint8(consensushashing.SigHashAll))

	fmt.Printf("\nGo Manual Preimage length: %d\n", buf.Len())
	fmt.Printf("Go Manual Preimage (hex): %s\n", hex.EncodeToString(buf.Bytes()))
}

func hexToBytes(hexStr string) []byte {
	bytes, err := hex.DecodeString(hexStr)
	if err != nil {
		log.Fatalf("Failed to decode hex: %v", err)
	}
	return bytes
}
