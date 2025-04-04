# Lucky Duck Pack

Lucky Duck Pack is a pioneering NFT collection that sets new standards for transparency, fairness, and true decentralization. Built on Ethereum, it represents one of the first truly unstoppable and verifiably fair NFT systems with genuine IP ownership and revenue-sharing for token holders.

## Overview

The Lucky Duck Pack project implements a collection of 10,000 NFTs with revolutionary features:

- **True Ownership**: Token holders own a fraction of the collection's IP and receive revenue rights
- **Provably Fair Distribution**: Verifiable randomness through Chainlink VRF ensures fair distribution
- **Automatic Revenue Sharing**: Direct royalty distribution for all NFT holders without staking
- **Unstoppable System**: Fully decentralized contracts with no admin controls after deployment
- **Perpetual Accessibility**: Redundant storage on both IPFS and Arweave for metadata persistence
- **Full Transparency**: On-chain provenance and immutable contract behavior

## Smart Contracts

The repository contains several smart contracts, each serving a specific purpose:

### Core Contracts

- **LuckyDuckPack.sol**: The ERC-721 NFT contract that handles token ownership, metadata, and collection reveal. Features a fair reveal mechanism using Chainlink VRF that prevents even the creators from predicting which token will receive which traits.

- **LDPMinter.sol**: Manages the minting process with a transparent and fair tiered pricing structure and Dutch auction mechanics. The contract includes safeguards against exploitation and ensures equitable access.

- **LDPRewarder.sol**: A revolutionary royalty distribution system that automatically shares secondary market royalties with all NFT holders. This contract eliminates the need for staking while ensuring proper revenue distribution.

- **LDPLuckyDraw.sol**: Facilitates verifiable random drawings for community giveaways using Chainlink VRF, ensuring transparent and fair community events.

### Architecture

```
                     ┌───────────────┐
                     │   Chainlink   │
                     │      VRF      │
                     └───────▲───────┘
                             │
 ┌───────────────┐    ┌──────┴────────┐    ┌───────────────┐
 │   LDPMinter   │◄───┤ LuckyDuckPack │───►│  LDPRewarder  │
 └───────────────┘    └───────────────┘    └───────────────┘
                              ▲
                              │
                     ┌────────┴────────┐
                     │   LDPLuckyDraw  │
                     └─────────────────┘
```

## Key Features Explained

### True Decentralization

Unlike most NFT projects that claim to be decentralized while retaining admin controls, Lucky Duck Pack burns all admin keys after deployment, creating a truly unstoppable system that cannot be altered, paused, or controlled by anyone - not even the creators.

### Fair Reveal Mechanism

After all tokens have been minted, a random offset number is generated using Chainlink VRF. This offset is applied to token IDs to determine the revealed metadata:

```
[Revealed ID] = ([Token ID] + [Offset]) % [Max Supply]
```

This transparent system ensures that no one - not even the project creators - can predict or manipulate which token receives which traits.

### Revolutionary Royalty Distribution

The LDPRewarder contract implements a groundbreaking approach to royalty distribution:

- When the collection earns royalties from secondary sales, 93.75% is distributed to NFT holders and 6.25% goes to the collection creator
- Holders don't need to stake their NFTs - simply owning the token entitles you to your share
- Rewards are tied to the tokens themselves, so if an NFT is sold with unclaimed rewards, the new owner has the right to claim them
- Supports multiple currencies (ETH, WETH, any ERC20) automatically
- Unstoppable and immutable - there is no admin role, and the creator can only change their payout address

### Commercial Rights & IP Ownership

As a Lucky Duck Pack NFT holder, you are granted an unlimited, worldwide, non-exclusive, royalty-free license to use, reproduce, and display the underlying artwork for commercial purposes, including creating and selling derivative work such as merchandise featuring the artwork. This represents true digital ownership - not just a JPG, but actual rights to the intellectual property.

## Technical Details

### Minting Process

The minting process is divided into phases with a dynamic pricing structure that includes optional Dutch auction mechanics if necessary. This approach ensures fair distribution while maximizing value for all stakeholders.

### Development Environment

The project uses:
- Solidity 0.8.23
- Truffle framework
- OpenZeppelin contracts
- Chainlink VRF for randomness

### Dependencies

- @chainlink/contracts: ^0.5.1
- @openzeppelin/contracts: ^4.7.3
- operator-filter-registry: ^1.3.0

### Contract Deployment

The contracts should be deployed in this order:
1. LuckyDuckPack.sol
2. LDPRewarder.sol
3. LDPMinter.sol
4. LDPLuckyDraw.sol

Then initialize the LuckyDuckPack contract with the addresses of the minter and rewarder contracts.

## Security Considerations

The contracts implement several security measures:

- Admin privileges are limited and burned after initialization
- No special backdoor functions
- Critical parameters are hardcoded to prevent manipulation
- Detailed validation on all inputs
- Protection against re-entrancy attacks
- Events for all important state changes

## Getting Started

### Prerequisites

- Node.js and npm
- Truffle Suite
- An Ethereum wallet with ETH for deployment

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/luckyduckspack.git
cd luckyduckspack
```

2. Install dependencies:
```bash
npm install
```

3. Compile the contracts:
```bash
truffle compile
```

4. Set up environment variables in a `.env` file:
```
CREATOR_ADDRESS=0x...
PAYOUT_ADDRESS=0x...
```

5. Run tests:
```bash
truffle test
```

### Deployment

1. Deploy to a testnet first:
```bash
USE_NFT_TESTNET_CONTRACTS=1 DEPLOY_NFT_CONTRACTS=1 truffle migrate --network goerli
```

2. Deploy to mainnet when ready:
```bash
DEPLOY_NFT_CONTRACTS=1 truffle migrate --network mainnet
```

## License

The smart contracts in this project are provided with the "UNLICENSED" identifier, meaning all rights are reserved and no license is granted to use, copy, modify, or distribute the code without explicit permission from the copyright holder.

## Disclaimer

This code is provided "as is", without warranty of any kind. The contracts are immutable after deployment, meaning the creator no longer has control over their behavior.
