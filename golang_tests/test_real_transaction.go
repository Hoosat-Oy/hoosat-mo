package main

import (
	"encoding/hex"
	"fmt"
	"log"

	"github.com/Hoosat-Oy/HTND/domain/consensus/model/externalapi"
	"github.com/Hoosat-Oy/HTND/domain/consensus/utils/consensushashing"
	"github.com/Hoosat-Oy/HTND/domain/consensus/utils/subnetworks"
	"github.com/Hoosat-Oy/HTND/domain/consensus/utils/utxo"
)

func main() {
	// Real transaction data from the Motoko logs
	// Transaction ID: 524b95d1e50111beeb7ce9020c0cb8a4042459a9acc7c172029edcbb3d37d3a9
	// Index: 1
	// Amount: 19999923000
	// Script: 210294eb83da2c7ad14c91a941ea2dbe22786b2eff5969ee794891dc55538fd67c37ab

	// Create transaction ID
	txIDBytes := hexToBytes("524b95d1e50111beeb7ce9020c0cb8a4042459a9acc7c172029edcbb3d37d3a9")
	var txIDArray [32]byte
	copy(txIDArray[:], txIDBytes)
	txID := externalapi.NewDomainTransactionIDFromByteArray(&txIDArray)

	// Create the real transaction from Motoko logs
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
				Value: 15000,
				ScriptPublicKey: &externalapi.ScriptPublicKey{
					Script:  hexToBytes("21020364e0d91f4557595ec5a1eda471b4c973cf01a1c2829ebc9b476aafc8ee23e3ab"),
					Version: 0,
				},
			},
			{
				Value: 19999898000,
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

	tx.Inputs[0].UTXOEntry = utxo.NewUTXOEntry(19999923000, utxoScript, false, 0)

	// Calculate signature hash using HTND
	reusedValues := &consensushashing.SighashReusedValues{}
	hash, err := consensushashing.CalculateSignatureHashECDSA(tx, 0, consensushashing.SigHashAll, reusedValues)
	if err != nil {
		log.Fatalf("Failed to calculate signature hash: %v", err)
	}

	fmt.Printf("Go HTND ECDSA Sighash for real transaction: %s\n", hash.String())
	fmt.Printf("Motoko ECDSA Sighash: c4ddd1567b53e3fa711751fb2a8757bc114ccc114f49421fc36a7b79e7f6ec09\n")

	if hash.String() == "c4ddd1567b53e3fa711751fb2a8757bc114ccc114f49421fc36a7b79e7f6ec09" {
		fmt.Println("✅ MATCH! Motoko implementation is correct")
	} else {
		fmt.Println("❌ MISMATCH! Motoko implementation needs fixing")
	}
}

func hexToBytes(hexStr string) []byte {
	bytes, err := hex.DecodeString(hexStr)
	if err != nil {
		log.Fatalf("Failed to decode hex: %v", err)
	}
	return bytes
}
