module Types {
  public type Outpoint = {
    transactionId: Text;
    index: Nat32;
  };

  public type TransactionInput = {
    previousOutpoint: Outpoint;
    signatureScript: Text;
    sequence: Nat64;
    sigOpCount: Nat8;
  };

  public type ScriptPublicKey = {
    version: Nat16;
    scriptPublicKey: Text;
  };

  public type TransactionOutput = {
    amount: Nat64;
    scriptPublicKey: ScriptPublicKey;
  };

  public type KaspaTransaction = {
    version: Nat16;
    inputs: [TransactionInput];
    outputs: [TransactionOutput];
    lockTime: Nat64;
    subnetworkId: Text;
    gas: Nat64;
    payload: Text;
  };

  public type UTXO = {
    transactionId: Text;
    index: Nat32;
    amount: Nat64;
    scriptPublicKey: Text;
    scriptVersion: Nat16;
    address: Text;
  };
}