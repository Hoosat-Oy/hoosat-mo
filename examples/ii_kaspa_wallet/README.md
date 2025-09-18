# Internet Identity + Kaspa Wallet Example

This example demonstrates how to build a complete Kaspa wallet application with Internet Identity authentication on the Internet Computer. Features a modern React frontend with shadcn-inspired dark theme and comprehensive wallet functionality.

## Features

- 🔐 **Internet Identity Authentication**: Passwordless login with biometrics or hardware keys
- 👤 **User Session Management**: Secure session handling with automatic timeout (24 hours)
- 📍 **Deterministic Address Generation**: Each user gets the same secure Kaspa address based on their II principal
- 💰 **Balance Checking**: View confirmed, unconfirmed, and immature balances for any address
- 💸 **Send Transactions**: Complete transaction building, signing, and broadcasting to Kaspa network
- 🌐 **Modern React Frontend**: Professional UI with shadcn-inspired dark theme
- 🔒 **Cryptographic Security**: SHA256-based derivation paths with collision resistance
- ⚡ **Real-time Updates**: Live balance checking and transaction status updates

## Architecture

### Backend (`backend.mo`)
- **Session Management**: Each II principal gets a separate wallet session with 24-hour timeout
- **Authentication**: Validates users and maintains secure sessions with anonymous access blocking
- **Wallet Operations**: Wraps the core Kaspa wallet functionality with user authentication
- **Secure Derivation Paths**: Uses SHA256 hash of principal converted to numeric derivation paths
- **Transaction Support**: Full send/receive functionality with proper error handling

### Frontend (React + Vite)
- **Modern React Architecture**: Clean component structure with hooks and state management
- **shadcn-inspired Design**: Professional dark theme with CSS custom properties
- **Internet Identity Integration**: Uses `@dfinity/auth-client` for seamless authentication
- **Responsive UI**: Mobile-first design with modern typography (Inter + JetBrains Mono)
- **Real-time Updates**: Live balance checking and transaction status updates
- **Comprehensive Error Handling**: User-friendly error messages and loading states

## Deployment

1. **Prerequisites:**
   ```bash
   # Install dependencies
   npm install

   # Start local IC replica
   dfx start --background

   # Deploy Internet Identity locally (required)
   dfx deps pull
   dfx deps init
   dfx deps deploy internet_identity
   ```

2. **Deploy the wallet canisters:**
   ```bash
   # Deploy backend
   dfx deploy ii_kaspa_wallet

   # Build and deploy React frontend
   cd frontend
   npm run build
   cd ..
   dfx deploy ii_wallet_frontend
   ```

3. **Access the wallet:**
   - Open the frontend URL from dfx deploy output (e.g., `http://[canister-id].localhost:4943/`)
   - Click "Login with Internet Identity"
   - Complete II authentication flow
   - Use wallet functions: get address, check balance, send transactions

## Usage Flow

1. **Authentication**
   - User clicks "🔐 Login with Internet Identity"
   - II redirects to biometric/hardware key authentication
   - User is authenticated and backend session is created
   - Frontend shows authenticated state with user principal

2. **Wallet Operations**
   - **Get Address**: Click "Get My Kaspa Address" to retrieve your deterministic address
   - **Check Balance**: Enter any Kaspa address or use "Use My Address" button
   - **Send KAS**: Fill recipient address and amount, click "Send KAS"
   - **Monitor Status**: Real-time status updates for all operations

3. **Session Management**
   - Sessions automatically timeout after 24 hours
   - Users can manually logout to clear sessions
   - Sessions don't persist across canister upgrades (for security)
   - Each II principal gets the same deterministic address every time

## Key Components

### Secure Derivation Path Generation
```motoko
// Convert principal to secure derivation path using SHA256
private func principalToDerivationPath(principal: Principal) : Text {
    let principalBytes = Principal.toBlob(principal);
    let hash = SHA256.fromBlob(#sha256, principalBytes);

    // Convert first 4 bytes to Nat32 (2^32 possible values)
    let hashBytes = Blob.toArray(hash);
    let pathBytes = Array.subArray(hashBytes, 0, 4);

    var value : Nat32 = 0;
    for (i in Iter.range(0, 3)) {
        value := value * 256 + Nat32.fromNat(Nat8.toNat(pathBytes[i]));
    };

    Nat32.toText(value) // Returns pure numeric string
};
```

### React Frontend Integration
```javascript
// Modern React hooks for authentication
const [isAuthenticated, setIsAuthenticated] = useState(false);
const [actor, setActor] = useState();

// Create authenticated actor after login
async function createAuthenticatedActor(authClient) {
    const identity = authClient.getIdentity();
    const agent = new HttpAgent({
        host: 'http://127.0.0.1:4943',
        identity
    });

    await agent.fetchRootKey(); // Local development

    const actor = Actor.createActor(idlFactory, {
        agent,
        canisterId: 'umunu-kh777-77774-qaaca-cai',
    });

    setActor(actor);
    return actor;
}
```

## Security Features

- **No Private Key Storage**: Uses IC's threshold ECDSA for key management
- **Cryptographic Derivation Paths**: SHA256 hash of principal ensures unique, collision-resistant paths
- **Principal-Based Access**: Each II principal has isolated wallet access
- **Session Timeouts**: Automatic session expiration after 24 hours
- **Anonymous Rejection**: Blocks anonymous access to wallet functions
- **Input Validation**: Comprehensive validation of all user inputs
- **Deterministic Security**: Same user always gets same address (no key loss risk)
- **2^32 Address Space**: Over 4 billion possible derivation paths

## Technology Stack

### Backend
- **Motoko**: Internet Computer smart contract language
- **Threshold ECDSA**: IC's built-in cryptographic key management
- **SHA256**: For secure derivation path generation
- **HTTP Outcalls**: For Kaspa mainnet API integration

### Frontend
- **React 18**: Modern frontend framework with hooks
- **Vite**: Fast build tool and development server
- **shadcn/ui Design System**: Professional dark theme with CSS custom properties
- **Inter & JetBrains Mono**: Modern typography
- **@dfinity/auth-client**: Internet Identity integration
- **@dfinity/agent**: IC canister communication

## Testing the Wallet

1. **Deploy locally** (see Deployment section above)
2. **Authenticate** with Internet Identity
3. **Get your address** and copy it
4. **Fund the address** using the test canister:
   ```bash
   # Send 1 KAS to your address
   dfx canister call kaspa_test_tecdsa send_kas '("your-address-here", 100000000)'
   ```
5. **Check balance** to see the funds appear
6. **Test sending** back to another address

## File Structure

```
examples/ii_kaspa_wallet/
├── README.md              # This documentation
├── backend.mo             # Motoko backend with II integration
└── frontend/              # React frontend application
    ├── package.json       # Frontend dependencies
    ├── vite.config.js     # Vite configuration
    ├── index.html         # Main HTML with font imports
    └── src/
        ├── main.jsx       # React app entry point
        ├── App.jsx        # Main wallet component
        └── index.css      # shadcn-inspired dark theme
```

## Production Considerations

- **Internet Identity URL**: Update to `https://identity.ic0.app` for mainnet
- **Canister IDs**: Update to production canister IDs in frontend
- **Error Monitoring**: Implement comprehensive logging and monitoring
- **Rate Limiting**: Add proper access controls and rate limiting
- **Backup Systems**: Consider implementing backup/recovery mechanisms
- **Transaction History**: Add persistent transaction storage
- **Advanced Features**: Multi-sig, address books, fee management

## Contributing

This example demonstrates the core concepts for building IC-based Kaspa wallets. Feel free to extend it with additional features like transaction history, multi-signature support, or integration with other IC canisters.