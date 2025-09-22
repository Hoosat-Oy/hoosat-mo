#!/bin/bash
# Setup environment variables for frontend

# Get canister IDs from dfx
BACKEND_CANISTER_ID=$(dfx canister id backend)

# Create .env file for frontend
cat > src/frontend/.env << EOF
VITE_CANISTER_ID_backend=${BACKEND_CANISTER_ID}
VITE_DFX_NETWORK=${DFX_NETWORK:-local}
EOF

echo "Environment setup complete!"
echo "Backend Canister ID: ${BACKEND_CANISTER_ID}"