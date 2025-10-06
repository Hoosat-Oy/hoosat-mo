import { AuthClient } from '@dfinity/auth-client';
import { Actor, HttpAgent } from '@dfinity/agent';
import React, { useState, useEffect } from 'react';

const canisterId = 'uxrrr-q7777-77774-qaaaq-cai';//'umunu-kh777-77774-qaaca-cai';
const network = process.env.DFX_NETWORK || 'local';
const identityProvider = network === 'ic'
  ? 'https://identity.ic0.app'
  : 'http://rdmx6-jaaaa-aaaaa-aaadq-cai.localhost:4943';

// IDL for our Kaspa wallet canister
const idlFactory = ({ IDL }) => {
  const KaspaError = IDL.Variant({
    'ValidationError': IDL.Record({ 'message': IDL.Text }),
    'NetworkError': IDL.Record({ 'message': IDL.Text, 'status_code': IDL.Opt(IDL.Nat) }),
    'CryptographicError': IDL.Record({ 'message': IDL.Text }),
    'InsufficientFunds': IDL.Record({ 'available': IDL.Nat64, 'required': IDL.Nat64 }),
    'InternalError': IDL.Record({ 'message': IDL.Text })
  });

  const AddressInfo = IDL.Record({
    'addr_type': IDL.Nat,
    'address': IDL.Text,
    'derivation_path': IDL.Text,
    'public_key': IDL.Vec(IDL.Nat8),
    'script_public_key': IDL.Text
  });

  const Balance = IDL.Record({
    'confirmed': IDL.Nat64,
    'unconfirmed': IDL.Nat64,
    'immature': IDL.Nat64,
    'total': IDL.Nat64
  });

  const TransactionResult = IDL.Record({
    'transaction_id': IDL.Text,
    'fee_paid': IDL.Nat64
  });

  return IDL.Service({
    'login': IDL.Func([], [IDL.Variant({ 'ok': IDL.Record({ 'principal': IDL.Text, 'session_created': IDL.Bool }), 'err': IDL.Text })], []),
    'logout': IDL.Func([], [IDL.Variant({ 'ok': IDL.Null, 'err': IDL.Text })], []),
    'whoami': IDL.Func([], [IDL.Variant({ 'ok': IDL.Record({ 'principal': IDL.Text, 'session_active': IDL.Bool }), 'err': IDL.Text })], []),
    'generateAddress': IDL.Func([], [IDL.Variant({ 'ok': AddressInfo, 'err': KaspaError })], []),
    'getBalance': IDL.Func([IDL.Text], [IDL.Variant({ 'ok': Balance, 'err': KaspaError })], []),
    'sendTransaction': IDL.Func([IDL.Text, IDL.Text, IDL.Nat64], [IDL.Variant({ 'ok': TransactionResult, 'err': KaspaError })], []),
  });
};

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [authClient, setAuthClient] = useState();
  const [actor, setActor] = useState();
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState();
  const [currentAddress, setCurrentAddress] = useState('');
  const [balance, setBalance] = useState(null);
  const [userInfo, setUserInfo] = useState(null);
  const [balanceAddress, setBalanceAddress] = useState('');
  const [sendToAddress, setSendToAddress] = useState('');
  const [sendAmount, setSendAmount] = useState('');

  useEffect(() => {
    updateActor();
  }, []);

  const showStatus = (message, type = 'info') => {
    setStatus({ message, type });
    setTimeout(() => setStatus(null), 5000);
  };

  async function updateActor() {
    try {
      const authClient = await AuthClient.create();
      setAuthClient(authClient);

      const isAuthenticated = await authClient.isAuthenticated();
      setIsAuthenticated(isAuthenticated);

      if (isAuthenticated) {
        await createAuthenticatedActor(authClient);
        await handlePostLogin();
      }
    } catch (error) {
      showStatus(`Failed to initialize: ${error.message}`, 'error');
    }
  }

  async function createAuthenticatedActor(authClient) {
    const identity = authClient.getIdentity();

    const agent = new HttpAgent({
      host: 'http://127.0.0.1:4943',
      identity
    });

    // Fetch root key for local development
    if (network !== 'ic') {
      await agent.fetchRootKey();
    }

    const actor = Actor.createActor(idlFactory, {
      agent,
      canisterId,
    });

    setActor(actor);
    return actor;
  }

  async function handlePostLogin(actorToUse = actor) {
    try {
      console.log('handlePostLogin: Calling backend login...');
      console.log('Using actor:', actorToUse);

      if (!actorToUse) {
        throw new Error('No actor available for backend login');
      }

      // Call backend login to establish session
      const loginResult = await actorToUse.login();
      console.log('Backend login result:', loginResult);

      if (loginResult.ok) {
        showStatus(`Welcome! Principal: ${loginResult.ok.principal}`, 'success');

        // Get user info
        const whoamiResult = await actorToUse.whoami();
        console.log('Whoami result:', whoamiResult);
        if (whoamiResult.ok) {
          setUserInfo(whoamiResult.ok);
        }
      } else {
        showStatus(`Backend login failed: ${loginResult.err}`, 'error');
      }
    } catch (error) {
      console.error('handlePostLogin error:', error);
      showStatus(`Connection error: ${error.message}`, 'error');
    }
  }

  async function login() {
    try {
      setLoading(true);
      showStatus('Connecting to Internet Identity...', 'info');

      await authClient.login({
        identityProvider,
        maxTimeToLive: BigInt(7 * 24 * 60 * 60 * 1000 * 1000 * 1000), // 7 days in nanoseconds
        onSuccess: async () => {
          console.log('Login success callback triggered');
          setIsAuthenticated(true);
          const newActor = await createAuthenticatedActor(authClient);
          console.log('Created actor:', newActor);
          await handlePostLogin(newActor);
          showStatus('Successfully logged in!', 'success');
        },
        onError: (error) => {
          console.error('Login error callback:', error);
          showStatus(`Login failed: ${error}`, 'error');
        }
      });
    } catch (error) {
      showStatus(`Login error: ${error.message}`, 'error');
    } finally {
      setLoading(false);
    }
  }

  async function logout() {
    try {
      setLoading(true);

      // Call backend logout
      if (actor) {
        await actor.logout();
      }

      await authClient.logout();
      setIsAuthenticated(false);
      setActor(null);

      // Clear state
      setCurrentAddress('');
      setBalance(null);
      setUserInfo(null);
      setBalanceAddress('');
      setSendToAddress('');
      setSendAmount('');

      showStatus('Logged out successfully', 'info');
    } catch (error) {
      showStatus(`Logout error: ${error.message}`, 'error');
    } finally {
      setLoading(false);
    }
  }

  async function getMyAddress() {
    if (!actor) {
      showStatus('No actor available - please login first', 'error');
      return;
    }

    try {
      setLoading(true);
      showStatus('Retrieving your Kaspa address...', 'info');

      console.log('getMyAddress: About to call backend...');
      const result = await actor.generateAddress();
      console.log('getMyAddress result:', result);

      if (result.ok) {
        setCurrentAddress(result.ok.address);
        showStatus('Address retrieved successfully!', 'success');
      } else {
        const errorMsg = result.err.ValidationError?.message ||
                        result.err.NetworkError?.message ||
                        result.err.InternalError?.message ||
                        'Unknown error';
        console.error('Get address error:', result.err);
        showStatus(`Failed to get address: ${errorMsg}`, 'error');
      }
    } catch (error) {
      console.error('getMyAddress exception:', error);
      showStatus(`Error: ${error.message}`, 'error');
    } finally {
      setLoading(false);
    }
  }

  async function checkBalance() {
    if (!actor || !balanceAddress.trim()) {
      showStatus('Please enter a valid Kaspa address', 'error');
      return;
    }

    try {
      setLoading(true);
      showStatus('Checking balance...', 'info');

      const result = await actor.getBalance(balanceAddress.trim());
      if (result.ok) {
        setBalance(result.ok);
        showStatus('Balance retrieved successfully!', 'success');
      } else {
        const errorMsg = result.err.ValidationError?.message ||
                        result.err.NetworkError?.message ||
                        result.err.InternalError?.message ||
                        'Unknown error';
        showStatus(`Failed to get balance: ${errorMsg}`, 'error');
      }
    } catch (error) {
      showStatus(`Error: ${error.message}`, 'error');
    } finally {
      setLoading(false);
    }
  }

  async function sendTransaction() {
    if (!actor || !currentAddress || !sendToAddress.trim() || !sendAmount.trim()) {
      showStatus('Please fill in all fields and get your address first', 'error');
      return;
    }

    try {
      setLoading(true);
      showStatus('Sending Kaspa transaction...', 'info');

      // Convert amount to sompi (smallest unit)
      const amountInSompi = BigInt(Math.floor(parseFloat(sendAmount) * 100000000));

      console.log('sendTransaction: About to call backend...');
      console.log('From:', currentAddress);
      console.log('To:', sendToAddress.trim());
      console.log('Amount (KAS):', sendAmount);
      console.log('Amount (sompi):', amountInSompi.toString());

      const result = await actor.sendTransaction(
        currentAddress,
        sendToAddress.trim(),
        amountInSompi
      );

      console.log('sendTransaction result:', result);

      if (result.ok) {
        showStatus('Transaction sent successfully!', 'success');
        // Clear send form
        setSendToAddress('');
        setSendAmount('');
        // Optionally refresh balance
        if (balanceAddress === currentAddress) {
          await checkBalance();
        }
      } else {
        const errorMsg = result.err.ValidationError?.message ||
                        result.err.NetworkError?.message ||
                        result.err.InsufficientFunds?.message ||
                        result.err.InternalError?.message ||
                        'Unknown error';
        console.error('Send transaction error:', result.err);
        showStatus(`Failed to send transaction: ${errorMsg}`, 'error');
      }
    } catch (error) {
      console.error('sendTransaction exception:', error);
      showStatus(`Error: ${error.message}`, 'error');
    } finally {
      setLoading(false);
    }
  }

  async function refreshUserInfo() {
    if (!actor) return;

    try {
      const result = await actor.whoami();
      if (result.ok) {
        setUserInfo(result.ok);
        showStatus('User info refreshed', 'success');
      }
    } catch (error) {
      showStatus(`Error: ${error.message}`, 'error');
    }
  }

  return (
    <div className={`container ${loading ? 'loading' : ''}`}>
      <h1>🔑 Kaspa Wallet with Internet Identity</h1>

      {/* Authentication Section */}
      <div className="card">
        <div className="auth-section">
          <h2>Authentication</h2>
          {!isAuthenticated ? (
            <div>
              <p>Connect with Internet Identity to access your secure Kaspa wallet</p>
              <button onClick={login} className="btn" disabled={loading}>
                {loading ? 'Connecting...' : '🔐 Login with Internet Identity'}
              </button>
            </div>
          ) : (
            <div>
              <p>✅ Connected to Internet Identity</p>
              {userInfo && (
                <div>
                  <p><strong>Principal:</strong> {userInfo.principal}</p>
                  <p><strong>Session:</strong> {userInfo.session_active ? 'Active' : 'Inactive'}</p>
                </div>
              )}
              <button onClick={refreshUserInfo} className="btn btn-secondary" disabled={loading}>
                Refresh Info
              </button>
              <button onClick={logout} className="btn btn-secondary" disabled={loading}>
                Logout
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Wallet Functions */}
      {isAuthenticated && (
        <div className="card">
          <div className="wallet-section">
            <h2>Wallet Functions</h2>

            {/* Address Display */}
            <div>
              <h3>Your Receive Address</h3>
              <button onClick={getMyAddress} className="btn" disabled={loading}>
                Get My Kaspa Address
              </button>
              {currentAddress && (
                <div className="address-display">
                  <strong>Your Address:</strong><br />
                  {currentAddress}
                  <br />
                  <small style={{color: '#666', marginTop: '8px', display: 'block'}}>
                    This is your personal receive address. It's always the same for your identity.
                  </small>
                </div>
              )}
            </div>

            {/* Balance Check */}
            <div>
              <h3>Check Balance</h3>
              <input
                type="text"
                placeholder="Enter any Kaspa address (e.g., kaspa:...)"
                value={balanceAddress}
                onChange={(e) => setBalanceAddress(e.target.value)}
                className="balance-input"
              />
              <br />
              <button onClick={checkBalance} className="btn" disabled={loading || !balanceAddress.trim()}>
                Check Balance
              </button>
              {currentAddress && (
                <button
                  onClick={() => setBalanceAddress(currentAddress)}
                  className="btn btn-secondary"
                  disabled={loading}
                  style={{marginLeft: '8px'}}
                >
                  Use My Address
                </button>
              )}
              {balance && (
                <div className="result-box">
                  <strong>Balance Information:</strong><br />
                  Confirmed: {balance.confirmed.toString()} sompi<br />
                  Unconfirmed: {balance.unconfirmed.toString()} sompi<br />
                  Immature: {balance.immature.toString()} sompi<br />
                  <strong>Total: {balance.total.toString()} sompi</strong>
                </div>
              )}
            </div>

            {/* Send Transaction */}
            <div>
              <h3>Send Kaspa</h3>
              <input
                type="text"
                placeholder="Recipient address (e.g., kaspa:...)"
                value={sendToAddress}
                onChange={(e) => setSendToAddress(e.target.value)}
                className="balance-input"
              />
              <br />
              <input
                type="number"
                placeholder="Amount in KAS (e.g., 0.5)"
                value={sendAmount}
                onChange={(e) => setSendAmount(e.target.value)}
                className="balance-input"
                step="0.00000001"
                min="0"
              />
              <br />
              <button
                onClick={sendTransaction}
                className="btn"
                disabled={loading || !currentAddress || !sendToAddress.trim() || !sendAmount.trim()}
              >
                Send KAS
              </button>
              <br />
              <small style={{color: '#666', marginTop: '8px', display: 'block'}}>
                {!currentAddress && '⚠️ Get your address first to enable sending'}
                {currentAddress && '💡 Make sure you have sufficient balance for the transaction + fees'}
              </small>
            </div>
          </div>
        </div>
      )}

      {/* Status Messages */}
      {status && (
        <div className={`status ${status.type}`}>
          {status.message}
        </div>
      )}

      {/* Footer Info */}
      <div className="card">
        <h3>About</h3>
        <p>This is a demonstration of Internet Identity integration with a Kaspa blockchain wallet on the Internet Computer.</p>
        <p><strong>Backend Canister:</strong> {canisterId}</p>
        <p><strong>Network:</strong> {network}</p>
      </div>
    </div>
  );
}

export default App;