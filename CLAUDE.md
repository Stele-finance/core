# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the Stele DeFi protocol - a decentralized investment challenge platform where users can participate in timed portfolio management competitions. The system allows users to join challenges, swap assets within virtual portfolios, compete for rankings, and mint performance NFTs as soulbound tokens.

### Core Architecture

- **Stele.sol**: Main protocol contract managing challenges, portfolio swaps, rankings, and rewards
- **StelePerformanceNFT.sol**: Soulbound NFT contract for minting performance achievement tokens
- **Token.sol**: ERC20 governance token contract for the protocol
- **SteleGovernor.sol**: OpenZeppelin governance contract for protocol decisions
- **TimeLock.sol**: Timelock controller for governance execution delays

### Key Components

**Challenge System**:
- 5 challenge types: OneWeek, OneMonth, ThreeMonths, SixMonths, OneYear (contracts/Stele.sol:11)
- Users join with entry fees and receive seed money in USD tokens (contracts/Stele.sol:322-366)
- Portfolio management through asset swapping using Uniswap V3 price oracles (contracts/Stele.sol:368-473)
- Real-time ranking system tracking top 5 performers (contracts/Stele.sol:518-569)

**Price Oracle Integration**:
- Uniswap V3 factory integration for price discovery (contracts/Stele.sol:234-284)
- ETH as intermediate price calculation token
- Multi-fee tier price checking (500, 3000, 10000 basis points)

**NFT Achievement System**:
- Soulbound NFTs for top 5 challenge performers (contracts/StelePerformanceNFT.sol)
- Performance metadata including rank, return rate, profit/loss percentage
- Non-transferable tokens bound to achievement owners

## Development Commands

### Environment Setup
```bash
nvm use 23
npm install
```

### Build and Compilation
```bash
npx hardhat compile
```

### Testing
```bash
# Run all tests on local hardhat network
npx hardhat test --network hardhat

# Run specific test file
npx hardhat test test/Stele.ts --network hardhat
```

### Deployment Commands

**Ethereum Mainnet:**
```bash
npx hardhat run scripts/1_deployToken.js --network mainnet
npx hardhat run scripts/2_deployTimeLock.js --network mainnet
npx hardhat run scripts/3_deployGovernor.js --network mainnet
npx hardhat run scripts/4_deployStele.js --network mainnet
```

**Arbitrum Network:**
```bash
npx hardhat run scripts/5_arbitrum_deployToken.js --network arbitrum
npx hardhat run scripts/6_arbitrum_deployTimeLock.js --network arbitrum
npx hardhat run scripts/7_arbitrum_deployGovernor.js --network arbitrum
npx hardhat run scripts/8_arbitrum_deployStele.js --network arbitrum
```

## Network Configuration

The project supports multiple networks configured in hardhat.config.ts:15:
- **hardhat**: Local development with mainnet forking
- **mainnet**: Ethereum mainnet deployment
- **arbitrum**: Arbitrum mainnet deployment  
- **base**: Base mainnet deployment

## Environment Variables

Create `.env` file in project root:
```
PRIVATE_KEY=your_private_key_here
INFURA_API_KEY=your_infura_api_key_here
ARBISCAN_API_KEY=your_arbiscan_api_key_here
```

## Key Contract Addresses

**Mainnet Deployment:**
- USD Token (USDC): 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
- WETH: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
- Uniswap V3 Factory: 0x1F98431c8aD98523631AE4a59f267346ea31F984

## Testing Strategy

The test suite uses mainnet forking to test against real Uniswap V3 liquidity:
- USDC whale account impersonation for test funding
- Real price oracle testing with multiple fee tiers
- Portfolio swap functionality with actual token pairs
- Challenge lifecycle testing (create → join → swap → register → rewards)

## Solidity Version & Compiler Settings

- **Solidity Version**: 0.7.6 and 0.8.8 (multi-compiler setup)
- **Optimizer**: Enabled with 1,000,000 runs for gas efficiency
- **ABI Encoder V2**: Required for complex struct returns

## Important Development Notes

- All price calculations use ETH as intermediate token for consistency
- SafeMath library used throughout for arithmetic operations (Solidity 0.7.6)
- Challenge rewards distributed in proportion to predefined ratios [50, 26, 13, 7, 4]
- Maximum 10 assets per portfolio enforced (contracts/Stele.sol:66)
- Entry fee set to 10 USD, seed money to 1000 USD by default (contracts/Stele.sol:115-116)
- NFTs are soulbound and cannot be transferred after minting