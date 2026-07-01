# 🗝️ Mythic Chest

**Provably Fair NFT Mystery Box powered by Chainlink VRF**

---

## 📖 Overview

**Mythic Chest** is an on-chain **NFT Mystery Box protocol** that uses **Chainlink VRF** to provide **provably fair, verifiable randomness** when distributing NFT rewards.

Users purchase a chest using an ERC-20 token and receive a **randomly selected ERC-1155 NFT** representing mythological weapons from **Greek, Roman, Egyptian, and Norse mythology**. Rewards are distributed across multiple rarity tiers, with probabilities enforced fully on-chain.

This project demonstrates **production-grade randomness handling**, **multi-token NFT architecture**, and **secure token-based payments**, designed with auditability and gas efficiency in mind.

---

## ✨ Key Features

* 🔐 **Provably Fair Randomness** via Chainlink VRF
* ⚔️ **ERC-1155 NFTs** for efficient multi-item minting
* 💰 **ERC-20 Token Payments** with explicit approvals
* 🎲 **Deterministic Random Expansion** from a single VRF seed
* 🧪 **Invariant & Unit Testing**
* 🔍 **Static Analysis–Driven Development**
* 🪙 **Gas-Conscious Design** for batch openings

---

## 🧠 Core Mechanism

Each chest opening follows a verifiable on-chain process:

1. User pays with the protocol’s ERC-20 token
2. A randomness request is sent to **Chainlink VRF**
3. Upon fulfillment:
   * A **rarity tier** is selected using a probability roll
   * A **mythology** is selected uniformly within that rarity
4. The corresponding **ERC-1155 NFT** is minted to the user

All randomness decisions are derived from the VRF response and are fully reproducible and auditable.

---

## 🧱 Contract Architecture

| Contract            | Responsibility                                                     |
| ------------------- | ------------------------------------------------------------------ |
| **Ankh.sol**        | ERC-20 token used to purchase chests                               |
| **Chest.sol**       | ERC-1155 contract representing unopened chests                     |
| **Prizes.sol**      | ERC-1155 contract containing all mythological weapon NFTs          |
| **MythicChest.sol** | Core protocol logic: payments, VRF integration, and reward minting |

The separation of concerns allows:

* Safer upgrades
* Easier auditing
* Cleaner mental models for reviewers

---

## 🎲 Randomness & Distribution

### Randomness Source

* **Chainlink VRF (v2)**
* Each chest opening generates a `requestId`
* The returned `randomWords[0]` value is used as a seed

### Randomness Usage

The protocol uses the `randomWords[0]` value returned by Chainlink VRF
to derive reward outcomes. The randomness is generated off-chain by
Chainlink and verified on-chain, ensuring unpredictability and fairness.

All selection logic is deterministic given the VRF output and can be
independently verified by recomputing the same operations on-chain.

---

## 📊 Rarity Probabilities

| Rarity    | Global Chance | Items per Tier | Per-Item Chance |
| --------- | ------------: | -------------: | --------------: |
| Common    |           70% |              4 |           17.5% |
| Uncommon  |           20% |              4 |              5% |
| Rare      |            8% |              4 |              2% |
| Legendary |            2% |              4 |            0.5% |

---

## 🗺️ Item Mapping

|    ID |   Rarity  |             Mythology            |
| ----: | :-------: | :------------------------------: |
|   1–4 |   Common  | Greek / Roman / Egyptian / Norse |
|   5–8 |  Uncommon | Greek / Roman / Egyptian / Norse |
|  9–12 |    Rare   | Greek / Roman / Egyptian / Norse |
| 13–16 | Legendary | Greek / Roman / Egyptian / Norse |

All items within a rarity tier are selected with **equal probability**.

---

## 🎮 User Flow

1. User approves the protocol to spend ERC-20 tokens
2. User purchases one or more chests
3. Chainlink VRF returns randomness
4. Reward rarity and mythology are derived on-chain
5. NFT reward is minted directly to the user

---

## 🛠️ Tech Stack

* **Solidity ^0.8.x**
* **Foundry** (testing & scripting)
* **Chainlink VRF**
* **OpenZeppelin Contracts**
* **Slither / Aderyn** (static analysis)

---

## 👨‍💻 Developer Setup

### Prerequisites

Make sure you have Foundry installed:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Clone and build

```bash
git clone --recurse-submodules https://github.com/Bomski-bit/MYTHIC-CHEST.git
cd super-mart

forge build
forge test
```

### If you already cloned without submodules

```bash
git submodule update --init --recursive
forge build
forge test
```

---

## 🔐 Security Considerations

This project was designed with a **security-first mindset**:

* Checks-Effects-Interactions ordering
* Explicit access control on admin functions
* No reliance on block variables for randomness
* Defensive assumptions documented explicitly

Privileged functions are intentional and part of the threat model.

---

## 🧪 Testing & Verification

* Unit tests for core logic
* Invariant tests for balance correctness
* Fuzzing via Foundry
* Static analysis using Slither and Aderyn

Some findings represent **known trade-offs** rather than exploitable vulnerabilities.

---

## 🎯 Threat Model & Assumptions

The protocol assumes:

* Admin keys are trusted and uncompromised
* Chainlink VRF behaves according to specification
* External token contracts follow ERC standards

The protocol does **not** attempt to defend against:

* Malicious governance
* Oracle collusion beyond Chainlink guarantees
* MEV or economic manipulation

---

## ⚠️ Known Limitations

* No external audit performed
* Admin privileges are centralized by design
* Economic modeling beyond randomness fairness is out of scope

---

## 📌 Notes on Design Decisions

* `abi.encodePacked` is used **only for string concatenation** and never passed to a hash function
* `rescueETH` and token recovery functions are **admin-only** and assume a trusted operator

---

## 📜 License

MIT

---

