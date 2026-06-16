# 💎 Diamond Proxy — Project README

> Built with Solidity `^0.8.20` and Foundry. Follows EIP-2535 Diamond Standard with a role-based access control system.

---

## Table of Contents

- [Project Structure](#project-structure)
- [Architecture Overview](#architecture-overview)
- [Key Design Decisions](#key-design-decisions)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Environment Setup](#environment-setup)
- [Build & Test](#build--test)
- [Deploy](#deploy)
- [Verification](#verification)
- [Upgrade Guide](#upgrade-guide)
- [Adding a New Facet](#adding-a-new-facet)
- [Security Considerations](#security-considerations)

---

## Project Structure

```
diamond-proxy/
│
├── src/
│   ├── Diamond.sol                          # Proxy entry point — permanent address
│   │
│   ├── facets/
│   │   ├── DiamondCutFacet.sol              # Upgrade logic (add/replace/remove)
│   │   ├── DiamondLoupeFacet.sol            # On-chain introspection (required EIP-2535)
│   │   ├── ConfigFacet.sol                  # Platform configuration (multisig, treasury, etc.)
│   │   └── TestFacet.sol                    # Example business logic facet
│   │
│   ├── libraries/
│   │   └── LibDiamond.sol                   # Core Diamond storage + selector routing logic
│   │
│   ├── interfaces/
│   │   ├── IMostroStructs.sol               # ALL shared structs and enums — single source of truth
│   │   ├── IConfigFacet.sol                 # ConfigFacet public ABI
│   │   ├── ITestFacet.sol                   # TestFacet public ABI
│   │   ├── IDiamondCut.sol                  # diamondCut() interface
│   │   ├── IDiamondLoupe.sol                # Loupe interface
│   │   └── IERC165.sol                      # Interface detection standard
│   │
│   ├── lib/
│   │   └── StorageLibraries.sol             # One namespaced storage library per domain
│   │
│   └── upgradeInitializers/
│       └── DiamondInit.sol                  # One-time initializer — seeds all storage atomically
│
├── script/
│   └── DeployDiamond.s.sol                  # Foundry deployment script
│
├── test/
│   └── (tests go here)
│
├── lib/
│   ├── forge-std/                           # Foundry standard library
│   └── openzeppelin-contracts/              # OZ utilities
│
├── .env                                     # Private keys and RPC URLs (never commit)
├── .env.example                             # Template for .env
├── .gitignore
├── foundry.toml                             # Foundry configuration
├── README.md                                # This file — project reference
├── VERIFICATION.md                          # Contract verification guide
└── verify-contracts.sh                      # Automated verification script
```

---

## Architecture Overview

```
                        ┌─────────────────────────────────────┐
                        │           Diamond.sol               │
                        │         (Proxy / Router)            │
                        │  fallback() routes all calls        │
                        └──────────────┬──────────────────────┘
                                       │ delegatecall
          ┌────────────────────────────┼────────────────────────┐
          │                            │                        │
          ▼                            ▼                        ▼
┌──────────────────┐       ┌──────────────────┐     ┌──────────────────┐
│ DiamondCutFacet  │       │DiamondLoupeFacet │     │   ConfigFacet    │
│  diamondCut()    │       │  facets()        │     │  getMultisig()   │
└──────────────────┘       │  facetAddresses()│     │  setMultisig()   │
                           └──────────────────┘     └──────────────────┘
          │
          ▼
┌──────────────────┐
│   TestFacet      │   ← Replace with your business logic
│  setValue()      │
│  getValue()      │
└──────────────────┘

        All facets share types via:
        ┌──────────────────────────────┐
        │      IMostroStructs.sol      │
        │  (structs & enums only)      │
        └──────────────────────────────┘

        Each domain owns its storage via:
        ┌──────────────────────────────┐
        │     StorageLibraries.sol     │
        │  TestStorage       → slot    │
        │  ManagerController → slot    │
        │  DiamondLayout     → slot    │
        └──────────────────────────────┘
```

---

## Key Design Decisions

### No OwnershipFacet
This project does **not** use a single-owner `OwnershipFacet` (ERC-173). Privileged actions are governed by an **ADMIN / SUPER_ADMIN role system** stored in `AccessControlStorage` and seeded at deployment via `DiamondInit`. `LibDiamond.contractOwner` guards `diamondCut()` only and is never exposed publicly.

### IMostroStructs Pattern
All structs and enums live in one place — `IMostroStructs.sol`. Every facet inherits it:
```solidity
contract MyFacet is IMostroStructs, IMyFacet { ... }
```

### Storage Libraries Pattern
Every facet domain has its own library in `StorageLibraries.sol` with a unique `keccak256` slot. **No direct state variables in facets — ever.**

### Typed DiamondInit
`DiamondInit.init()` receives a typed `InitParams` struct. All domain storage is seeded atomically inside the single `diamondCut` call at deployment. If `init()` reverts, the entire deployment reverts.

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Foundry | Latest | `curl -L https://foundry.paradigm.xyz \| bash` then `foundryup` |
| Git | Any | System package manager |

Verify:
```bash
forge --version
cast --version
anvil --version
```

---

## Installation

```bash
# Clone repository
git clone <repo-url>
cd <repo-name>

# Install dependencies
forge install
```

Dependencies installed:
- `forge-std` - Foundry standard library
- `openzeppelin-contracts` - OpenZeppelin utilities

---

## Environment Setup

### 1. Create `.env` File

```bash
# Copy example environment file
cp .env.example .env

# Edit with your values
nano .env  # or vim, code, etc.
```

### 2. Configure `.env`

```bash
# ==============================================================
# DEPLOYMENT CONFIGURATION
# ==============================================================

# Deployer private key (WITHOUT 0x prefix for Foundry)
PRIVATE_KEY=your_private_key_here

# ==============================================================
# AVALANCHE RPC ENDPOINTS
# ==============================================================

# Fuji Testnet RPC
FUJI_RPC_URL=https://api.avax-test.network/ext/bc/C/rpc

# Avalanche Mainnet RPC
AVALANCHE_RPC_URL=https://api.avax.network/ext/bc/C/rpc

# Alternative RPCs (optional):
# FUJI_RPC_URL=https://rpc.ankr.com/avalanche_fuji
# AVALANCHE_RPC_URL=https://rpc.ankr.com/avalanche

# ==============================================================
# CONTRACT VERIFICATION
# ==============================================================

# Snowtrace API Key (get from https://snowtrace.io/myapikey)
SNOWTRACE_API_KEY=your_snowtrace_api_key_here

# ==============================================================
# PROJECT-SPECIFIC ADDRESSES (update before deployment)
# ==============================================================

# Multisig/Treasury address
MULTISIG_ADDRESS=0xYourMultisigAddress

# Admin addresses
SUPER_ADMIN_ADDRESS=0xYourSuperAdminAddress
SECOND_ADMIN_ADDRESS=0xYourSecondAdminAddress

# Protocol addresses (if applicable)
TREASURY_ADDRESS=0xYourTreasuryAddress
USDC_ADDRESS=0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E  # USDC on Avalanche
```

### 3. Security Check

```bash
# Verify .env is in .gitignore
cat .gitignore | grep ".env"

# Should show:
# .env
# .env.local
```

> ⚠️ **CRITICAL**: Never commit `.env` to version control. It contains your private keys!

### 4. Load Environment

```bash
# Load environment variables
source .env

# Verify loaded (should show your RPC URL)
echo $FUJI_RPC_URL
```

---

## Build & Test

### Compile Contracts

```bash
# Build all contracts
forge build

# Build with size report
forge build --sizes

# Force clean rebuild
forge clean && forge build
```

### Run Tests

```bash
# Run all tests
forge test

# Run with verbose output
forge test -vv

# Run with gas reporting
forge test --gas-report

# Run specific test
forge test --match-contract DiamondTest

# Run with maximum verbosity (shows traces)
forge test -vvvv
```

---

## Deploy

### Pre-Deployment Checklist

Before deploying to any network:

- [ ] `.env` file configured with correct values
- [ ] `PRIVATE_KEY` has sufficient AVAX for gas
- [ ] All tests passing (`forge test`)
- [ ] Contracts compiled without warnings (`forge build`)
- [ ] Reviewed deployment script (`script/DeployDiamond.s.sol`)

### Get Testnet AVAX

```bash
# Visit Avalanche Faucet
https://faucet.avax.network/

# Enter your wallet address
# Receive free AVAX for Fuji testnet
```

### Local Deployment (Testing)

```bash
# Terminal 1: Start local Anvil node
anvil

# Terminal 2: Deploy to local node
forge script script/DeployDiamond.s.sol \
    --rpc-url http://127.0.0.1:8545 \
    --broadcast \
    -vvvv
```

### Fuji Testnet Deployment

```bash
# Load environment variables
source .env

# Deploy to Fuji testnet with verification
forge script script/DeployDiamond.s.sol \
    --rpc-url $FUJI_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --etherscan-api-key $SNOWTRACE_API_KEY \
    -vvvv

# Alternative: Using environment variable directly
forge script script/DeployDiamond.s.sol \
    --rpc-url fuji \
    --broadcast \
    --verify \
    -vvvv
```

### Avalanche Mainnet Deployment

> ⚠️ **MAINNET WARNING**: Deploying to mainnet is permanent and uses real AVAX. Ensure thorough testing on Fuji first!

**Pre-Mainnet Checklist:**
- [ ] Contracts audited by professional security firm
- [ ] All tests passing on Fuji for 1+ week
- [ ] Deployer wallet has 5+ AVAX for gas
- [ ] Team review of deployment script
- [ ] Multisig addresses confirmed
- [ ] Backup of private keys secured

```bash
# Load environment
source .env

# DRY RUN: Simulate deployment without broadcasting
forge script script/DeployDiamond.s.sol \
    --rpc-url $AVALANCHE_RPC_URL \
    --private-key $PRIVATE_KEY \
    -vvvv

# ACTUAL DEPLOYMENT: Only run after successful dry run
forge script script/DeployDiamond.s.sol \
    --rpc-url $AVALANCHE_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --etherscan-api-key $SNOWTRACE_API_KEY \
    -vvvv

# Optional: Set custom gas price (in gwei)
forge script script/DeployDiamond.s.sol \
    --rpc-url $AVALANCHE_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --etherscan-api-key $SNOWTRACE_API_KEY \
    --with-gas-price 30000000000 \
    -vvvv
```

### Expected Output

```
=== Phase 1: Deploying Diamond Core ===
DiamondCutFacet: 0x1234...abcd
Diamond:         0x5678...ef01

=== Phase 2: Deploying Facets ===
DiamondLoupeFacet: 0xabcd...1234
ConfigFacet:       0xef01...5678
TestFacet:         0x2345...6789

=== Phase 3: Deploying DiamondInit ===
DiamondInit:       0x6789...abcd

=== Phase 4: Building FacetCuts ===
FacetCuts prepared: 3 facets

=== Phase 5: Executing DiamondCut ===
DiamondCut executed successfully

=== Phase 6: Post-Deployment Verification ===
Facets installed: 4
Owner verified:   0xYourAddress

=== DEPLOYMENT COMPLETE ===
Deployer:          0xYourAddress
Diamond:           0x5678...ef01
DiamondCutFacet:   0x1234...abcd
DiamondLoupeFacet: 0xabcd...1234
ConfigFacet:       0xef01...5678
TestFacet:         0x2345...6789
DiamondInit:       0x6789...abcd

Diamond is ready for use

To verify contracts, run:
  chmod +x verify-contracts.sh
  ./verify-contracts.sh
```

### Save Deployment Addresses

```bash
# Deployment info saved to:
broadcast/DeployDiamond.s.sol/<chain-id>/run-latest.json

# Extract Diamond address (Fuji)
cat broadcast/DeployDiamond.s.sol/43113/run-latest.json | \
    jq -r '.transactions[] | select(.contractName == "Diamond") | .contractAddress'

# Extract all addresses
cat broadcast/DeployDiamond.s.sol/43113/run-latest.json | \
    jq '.transactions[] | {contractName, contractAddress}'
```

> 📌 **Share only the Diamond address** with users. All facet addresses are internal implementation details.

---

## Verification

After deployment, verify all contracts so ABIs are indexed on Snowtrace.

### Automated Verification

```bash
# Make script executable
chmod +x verify-contracts.sh

# Run verification (auto-extracts addresses from deployment)
./verify-contracts.sh

# Script will verify:
# - DiamondCutFacet
# - Diamond (with constructor args)
# - DiamondLoupeFacet
# - ConfigFacet
# - TestFacet
# - DiamondInit
```

### Manual Verification

If automated verification fails, see [VERIFICATION.md](./VERIFICATION.md) for detailed manual verification steps.

### Check Verification Status

Visit Snowtrace:
- **Fuji**: `https://testnet.snowtrace.io/address/YOUR_DIAMOND_ADDRESS`
- **Mainnet**: `https://snowtrace.io/address/YOUR_DIAMOND_ADDRESS`

Look for:
- ✅ Green checkmark on contract
- ✅ "Contract Source Code Verified" message
- ✅ "Read Contract" and "Write Contract" tabs visible

---

## Upgrade Guide

The Diamond address **never changes**. Upgrades deploy a new facet and call `diamondCut()`.

```solidity
TestFacetV2 newFacet = new TestFacetV2();

bytes4[] memory selectors = new bytes4[](1);
selectors[0] = TestFacetV2.getValue.selector;

IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
cut[0] = IDiamondCut.FacetCut({
    facetAddress:      address(newFacet),
    action:            IDiamondCut.FacetCutAction.Replace,
    functionSelectors: selectors
});

IDiamondCut(diamondAddress).diamondCut(cut, address(0), "");
```

| Action | When to use |
|---|---|
| `Add` | New functions that don't exist yet |
| `Replace` | Upgrade existing functions to a new implementation |
| `Remove` | Permanently delete functions |

---

## Adding a New Facet

Every new facet requires exactly these four steps:

**1. Add struct to `IMostroStructs.sol`**
```solidity
struct MyFeatureData {
    uint256 someValue;
}
```

**2. Add storage library to `StorageLibraries.sol`**
```solidity
library MyFeatureStorage {
    bytes32 internal constant STORAGE_SLOT =
        keccak256("mostro.storage.my.feature");

    function layout()
        internal
        view
        returns (IMostroStructs.MyFeatureData storage l)
    {
        bytes32 slot = STORAGE_SLOT;
        assembly { l.slot := slot }
    }
}
```

**3. Create `src/interfaces/IMyFacet.sol`**
```solidity
interface IMyFacet {
    function getSomeValue() external view returns (uint256);
    function setSomeValue(uint256 value) external;
}
```

**4. Create `src/facets/MyFacet.sol`**
```solidity
contract MyFacet is IMostroStructs, IMyFacet {
    function getSomeValue() external view override returns (uint256) {
        return MyFeatureStorage.layout().someValue;
    }
    function setSomeValue(uint256 _value) external override {
        MyFeatureStorage.layout().someValue = _value;
    }
}
```

Then register it in `DeployDiamond.s.sol` — Phase 2 (deploy) and Phase 4 (selectors).

---

## Security Considerations

1. **Multisig as deployer** — set `contractOwner` to a Gnosis Safe in production, not an EOA.
2. **Role seeding** — the first super-admin seeded in `DiamondInit` has broad power. Set carefully.
3. **Initializer guard** — `DiamondInit.init()` runs once. Add `require(!isInit)` guard if needed.
4. **Selector clashes** — verify no two facets share the same 4-byte selector before deploying.
5. **Struct immutability** — never reorder fields in `IMostroStructs`. Always append new fields.
6. **Audit before mainnet** — get a professional audit before deploying with real funds.

---

## Useful Commands

```bash
# Check wallet balance
cast balance YOUR_ADDRESS --rpc-url $FUJI_RPC_URL

# Check current gas price
cast gas-price --rpc-url $FUJI_RPC_URL

# Get deployer address from private key
cast wallet address --private-key $PRIVATE_KEY

# Call Diamond function
cast call DIAMOND_ADDRESS "facetAddresses()(address[])" --rpc-url $FUJI_RPC_URL

# Send transaction
cast send DIAMOND_ADDRESS "functionName(uint256)" 123 \
    --private-key $PRIVATE_KEY \
    --rpc-url $FUJI_RPC_URL

# Check if contract has code (verify deployment)
cast code DIAMOND_ADDRESS --rpc-url $FUJI_RPC_URL
```

---

## Network Information

### Avalanche Fuji Testnet
- **Chain ID**: 43113
- **RPC**: https://api.avax-test.network/ext/bc/C/rpc
- **Explorer**: https://testnet.snowtrace.io
- **Faucet**: https://faucet.avax.network/
- **Currency**: AVAX (testnet - no real value)

### Avalanche C-Chain Mainnet
- **Chain ID**: 43114
- **RPC**: https://api.avax.network/ext/bc/C/rpc
- **Explorer**: https://snowtrace.io
- **Currency**: AVAX (real value)

---

## Resources

- [EIP-2535 Specification](https://eips.ethereum.org/EIPS/eip-2535)
- [Louper.dev — Diamond Explorer](https://louper.dev)
- [Foundry Book](https://book.getfoundry.sh)
- [Avalanche Documentation](https://docs.avax.network/)
- [Snowtrace API Docs](https://docs.snowtrace.io/)
- [Avalanche Fuji Faucet](https://faucet.avax.network)
- [VERIFICATION.md](./VERIFICATION.md) — Contract verification guide

---

## License

MIT
