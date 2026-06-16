# 📚 Diamond Proxy — EIP-2535 Learning Guide

> A complete explanation of the Diamond Standard for developers who want to understand how it works, why it exists, and how to use it correctly.

---

## Table of Contents

- [What is the Diamond Proxy?](#what-is-the-diamond-proxy)
- [Why Use a Diamond?](#why-use-a-diamond)
- [How It Works](#how-it-works)
- [The Facet Pattern](#the-facet-pattern)
- [Namespaced Storage](#namespaced-storage)
- [DiamondCut — Upgrading](#diamondcut--upgrading)
- [DiamondLoupe — Introspection](#diamondloupe--introspection)
- [DiamondInit — Initialisation](#diamondinit--initialisation)
- [Key Concepts Glossary](#key-concepts-glossary)
- [Common Mistakes](#common-mistakes)
- [Resources](#resources)

---

## What is the Diamond Proxy?

The **Diamond Proxy** (EIP-2535) is an upgradeable smart contract pattern that solves the biggest limitations of traditional proxy patterns like Transparent Proxy and UUPS.

In a traditional proxy:
- You have **one implementation contract**
- It has a **24KB size limit** (the EVM hard limit)
- Upgrading replaces the **entire implementation**

In a Diamond:
- You have **one proxy contract** (the Diamond)
- It routes calls to **many small implementation contracts** called **Facets**
- Each Facet holds a piece of the logic
- You can upgrade **individual functions** without touching anything else
- There is **no effective size limit** — just add more facets

```
Traditional Proxy          Diamond Proxy
─────────────────          ─────────────────────────────────────

  User                       User
   │                          │
   ▼                          ▼
 Proxy          ──►        Diamond (proxy)
   │                          │
   ▼                          ├──► FacetA  (functions 1-10)
 Implementation               ├──► FacetB  (functions 11-20)
 (one contract,               ├──► FacetC  (functions 21-30)
  max 24KB)                   └──► FacetD  (functions 31-40)
                           (unlimited functions, no size limit)
```

---

## Why Use a Diamond?

| Feature | Transparent Proxy | UUPS | Diamond (EIP-2535) |
|---|---|---|---|
| Upgradeable | ✅ | ✅ | ✅ |
| 24KB size limit bypass | ❌ | ❌ | ✅ |
| Upgrade individual functions | ❌ | ❌ | ✅ |
| On-chain introspection | ❌ | ❌ | ✅ |
| Multi-facet logic separation | ❌ | ❌ | ✅ |
| Storage collision safe | ⚠️ | ⚠️ | ✅ |
| Industry adoption | High | High | Growing fast |

**Best suited for:**
- DeFi protocols with many modules (lending, staking, governance)
- Large NFT/gaming contracts that exceed 24KB
- Protocols that need surgical upgrades without full redeployments
- Any system where logic separation and long-term upgradeability matters

---

## How It Works

### The Call Flow

When a user calls any function on the Diamond address:

```
1. User sends TX to Diamond address
        │
        ▼
2. Diamond.fallback() fires
        │
        ▼
3. msg.sig (4-byte function selector) is looked up
   in the selectorToFacetAndPosition mapping
        │
        ▼
4. The facet address is retrieved
        │
        ▼
5. delegatecall forwards the call to the facet
        │
        ▼
6. Facet logic executes in the Diamond's storage context
        │
        ▼
7. Result is returned to the user
```

### The Key Insight: `delegatecall`

`delegatecall` means the facet's **code** runs, but the Diamond's **storage** is read and written. The facet itself never holds any state. This means you can upgrade the logic (deploy a new facet) without ever touching the stored data.

```
Diamond Storage                Facet Code
───────────────                ──────────
slot 0: owner                  function setValue(uint256 x) {
slot 1: value        ◄──────       storage.value = x;   // writes to Diamond's slot 1
slot 2: balances               }
```

---

## The Facet Pattern

Every facet in this project follows a strict four-layer pattern. This is the **golden rule** — never deviate from it.

```
Layer 1: IMostroStructs.sol   — struct/enum definitions (shared, no storage)
Layer 2: StorageLibraries.sol — namespaced keccak256 storage slot per domain
Layer 3: IMyFacet.sol         — public ABI interface
Layer 4: MyFacet.sol          — business logic only
```

### ❌ Wrong — the old inline pattern
```solidity
library LibTest {
    struct TestStorage { uint256 value; }

    function testStorage() internal pure returns (TestStorage storage ts) {
        bytes32 pos = keccak256("diamond.test.storage");
        assembly { ts.slot := pos }
    }
}

contract TestFacet {
    function setValue(uint256 _value) external {
        LibTest.testStorage().value = _value;
    }
}
```

### ✅ Correct — the four-layer pattern
```solidity
// Layer 1 — IMostroStructs.sol
interface IMostroStructs {
    struct TestData { uint256 value; }
}

// Layer 2 — StorageLibraries.sol
library TestStorage {
    bytes32 internal constant STORAGE_SLOT = keccak256("mostro.storage.test");
    function layout() internal view returns (IMostroStructs.TestData storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly { l.slot := slot }
    }
}

// Layer 3 — ITestFacet.sol
interface ITestFacet {
    function setValue(uint256 value) external;
    function getValue() external view returns (uint256);
}

// Layer 4 — TestFacet.sol
contract TestFacet is IMostroStructs, ITestFacet {
    function setValue(uint256 _value) external override {
        TestStorage.layout().value = _value;
    }
    function getValue() external view override returns (uint256) {
        return TestStorage.layout().value;
    }
}
```

---

## Namespaced Storage

### Why it matters

The EVM stores contract state in 32-byte slots numbered from 0 upward. Regular Solidity contracts use slots sequentially — `slot 0`, `slot 1`, `slot 2`, etc. In a Diamond with many facets, if two facets naively use slot 0, they overwrite each other.

**Namespaced storage** solves this by jumping to a pseudo-random slot using `keccak256`:

```solidity
bytes32 constant SLOT = keccak256("mostro.storage.test");
// SLOT = 0x3f4218... (a near-random 32-byte position far from slot 0)

assembly {
    l.slot := SLOT
}
```

The probability of two different strings producing the same hash is astronomically small. By convention, use a descriptive namespaced string like `"mostro.storage.<domain>"`.

### Rules

- Every storage library must have a **unique slot string** — never reuse one
- Use the naming convention `"mostro.storage.<domain>"` for consistency
- Storage getter functions must be `internal view` — not `pure` (returning a storage pointer is a state read)
- Never add new fields in the middle of a struct — always **append at the end**

---

## DiamondCut — Upgrading

`diamondCut()` is how functions are added, replaced, or removed from the Diamond. It is the only upgrade mechanism.

```solidity
function diamondCut(
    FacetCut[] calldata _diamondCut,  // what to change
    address _init,                     // optional initializer contract
    bytes calldata _calldata           // calldata for initializer
) external;
```

### FacetCut struct

```solidity
struct FacetCut {
    address facetAddress;       // the facet to wire up (address(0) for Remove)
    FacetCutAction action;      // Add / Replace / Remove
    bytes4[] functionSelectors; // which selectors to affect
}
```

### Actions

| Action | What it does |
|---|---|
| `Add` | Registers new selectors pointing to a new facet |
| `Replace` | Re-points existing selectors to a new facet address |
| `Remove` | Deletes selectors from the registry entirely |

### Who can call it?

Only `LibDiamond.contractOwner` — set in the Diamond constructor. In production this should be a multisig, not an EOA.

---

## DiamondLoupe — Introspection

The `DiamondLoupeFacet` implements `IDiamondLoupe` — **required by EIP-2535**. It lets anyone inspect the Diamond on-chain.

```solidity
// Returns all facets and their selectors
function facets() external view returns (Facet[] memory);

// Returns all selectors for a given facet address
function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory);

// Returns all registered facet addresses
function facetAddresses() external view returns (address[] memory);

// Returns the facet address for a given selector
function facetAddress(bytes4 _functionSelector) external view returns (address);
```

Tools like [Louper.dev](https://louper.dev) use this to visualise your Diamond in a browser.

---

## DiamondInit — Initialisation

`DiamondInit` is a one-time contract called via `delegatecall` during the first `diamondCut`. It runs in the Diamond's storage context and seeds initial state for all domains at once.

```solidity
contract DiamondInit is IMostroStructs {

    struct InitParams {
        bool isInit;
        // add domain params here as you add facets
    }

    function init(InitParams calldata p) external {
        // check upgrade-owner is set
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(ds.contractOwner != address(0), "DiamondInit: no owner");

        // seed your storage libs here
        DiamondLayoutStorage.layout().isInit = p.isInit;
    }
}
```

**Key rules:**
- Never call it directly — only as `_init` argument in `diamondCut()`
- If `init()` reverts, the entire `diamondCut` reverts — no partial state
- Extend `InitParams` as you add new facet domains
- Consider adding `require(!isInit)` to prevent double-initialisation

---

## Key Concepts Glossary

| Term | Definition |
|---|---|
| **Diamond** | The single proxy contract at a permanent address that routes all calls |
| **Facet** | A deployed contract containing logic only — no storage of its own |
| **Selector** | The first 4 bytes of `keccak256("functionName(paramTypes)")` — the function's unique ID |
| **DiamondCut** | The operation of adding, replacing, or removing selectors/facets |
| **Loupe** | The EIP-2535 introspection interface — lets you inspect the Diamond's current state |
| **Diamond Storage** | A pattern using `keccak256` slot positioning to avoid storage collisions |
| **delegatecall** | EVM opcode that runs another contract's code in the caller's storage context |
| **Namespaced Storage** | Each library claims its own unique storage slot — facets never collide |
| **IMostroStructs** | Shared interface holding all structs and enums used across facets |
| **StorageLibraries** | File containing one storage lib per domain, each with a unique slot |
| **_init** | A contract `delegatecall`ed during `diamondCut` to initialise state — used once |
| **InitParams** | Typed struct passed to `DiamondInit.init()` — all bootstrap data in one place |
| **msg.sig** | The 4-byte function selector of the current call — used by `fallback()` for routing |

---

## Common Mistakes

### ❌ Using state variables directly in a facet
```solidity
// WRONG — slot 0 could overwrite critical Diamond data
contract MyFacet {
    uint256 public value;
}

// CORRECT
contract MyFacet is IMostroStructs, IMyFacet {
    function setValue(uint256 v) external override {
        MyStorage.layout().value = v;
    }
}
```

### ❌ Defining storage structs inline inside a facet file
```solidity
// WRONG — struct and slot belong in separate dedicated files
library LibMyFacet {
    struct MyStorage { uint256 value; }
}

// CORRECT
// struct → IMostroStructs.sol
// slot   → StorageLibraries.sol
```

### ❌ Using `internal pure` for storage pointer getters
```solidity
function layout() internal pure returns (MyStruct storage l) { ... }  // ❌ pure is wrong
function layout() internal view returns (MyStruct storage l) { ... }  // ✅ view is correct
```

### ❌ Forgetting `0x` prefix on private key in `.env`
```bash
PRIVATE_KEY=abc123...      # ❌
PRIVATE_KEY=0xabc123...    # ✅
```

### ❌ Using fixed-size arrays where dynamic arrays are required
```solidity
bytes4[5] memory selectors;                  // ❌ cannot pass to bytes4[] parameter
bytes4[] memory selectors = new bytes4[](5); // ✅
```

### ❌ Adding a new facet without updating IMostroStructs and StorageLibraries
Every new facet domain needs its struct in `IMostroStructs` and its library in `StorageLibraries`. Skipping either causes a storage collision or compile error.

### ❌ Reordering fields in an existing struct
```solidity
// DEPLOYED (never change field order)
struct MyData { uint256 a; uint256 b; }

// WRONG upgrade — swapping order corrupts storage
struct MyData { uint256 b; uint256 a; }

// CORRECT upgrade — always append
struct MyData { uint256 a; uint256 b; uint256 c; }
```

---

## Resources

- [EIP-2535 Official Specification](https://eips.ethereum.org/EIPS/eip-2535)
- [Louper.dev — Diamond Explorer](https://louper.dev)
- [Nick Mudge's Reference Implementation](https://github.com/mudgen/diamond-3-hardhat)
- [Foundry Book](https://book.getfoundry.sh)
- [Avalanche Fuji Faucet](https://faucet.avax.network)