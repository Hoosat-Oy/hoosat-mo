#!/usr/bin/env node
import { readFileSync, writeFileSync } from 'fs';
import { join } from 'path';

try {
  // Read canister_ids.json from .dfx/local directory
  const canisterIds = JSON.parse(readFileSync('../../.dfx/local/canister_ids.json', 'utf8'));

  // Get backend canister ID
  const backendId = canisterIds.backend?.local || canisterIds.backend?.ic;

  if (!backendId) {
    console.error('Backend canister ID not found. Make sure to deploy first with: dfx deploy');
    process.exit(1);
  }

  // Create .env file
  const envContent = `VITE_CANISTER_ID_backend=${backendId}
VITE_DFX_NETWORK=${process.env.DFX_NETWORK || 'local'}
`;

  writeFileSync('.env', envContent);
  console.log(`✅ Environment setup complete!`);
  console.log(`Backend Canister ID: ${backendId}`);

} catch (error) {
  console.error('Error setting up environment:', error.message);
  console.log('Make sure to run "dfx deploy" first to generate canister IDs');
  process.exit(1);
}