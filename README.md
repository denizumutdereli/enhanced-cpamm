# Enhanced Constant Product Automated Market Maker (CPAMM)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A robust and feature-rich implementation of a Constant Product Automated Market Maker (CPAMM) smart contract built on Ethereum. This contract provides a decentralized exchange mechanism for ERC20 token pairs with enhanced security features, upgradability, and optimized gas usage.

## Table of Contents

- [Enhanced Constant Product Automated Market Maker (CPAMM)](#enhanced-constant-product-automated-market-maker-cpamm)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Usage](#usage)
  - [Contract Functions](#contract-functions)
    - [Core Functions](#core-functions)
    - [Administrative Functions](#administrative-functions)
    - [View Functions](#view-functions)
  - [Mathematical Foundations](#mathematical-foundations)
  - [Security Considerations](#security-considerations)
  - [Contributing](#contributing)
  - [License](#license)
  - [Contact](#contact)

## Features

- Constant Product AMM implementation
- Upgradeable contract architecture
- Slippage protection for swaps and liquidity operations
- Basic price oracle functionality
- Flash loan attack mitigation
- Fee accrual and collection mechanism
- Emergency pause functionality
- Token rescue capability for contract owner
- Comprehensive event logging
- Gas-optimized operations

## Prerequisites

- Node.js (v12.0.0 or later)
- npm (v6.0.0 or later)
- Hardhat
- OpenZeppelin Contracts

## Installation

1. Clone the repository:
   ```
   git clone https://github.com/denizumutdereli/enhanced-cpamm.git
   cd enhanced-cpamm
   ```

2. Install dependencies:
   ```
   npm install
   ```

3. Compile the contracts:
   ```
   npx hardhat compile
   ```

## Usage

1. Deploy the contract:
   ```
   npx hardhat run scripts/deploy.js --network <your-network>
   ```

2. Interact with the contract using Hardhat console or by writing custom scripts.

## Contract Functions

### Core Functions

- `swap`: Exchange tokens with slippage protection
- `addLiquidity`: Provide liquidity to the pool
- `removeLiquidity`: Remove liquidity from the pool

### Administrative Functions

- `setFeeRecipient`: Set the address to receive collected fees
- `collectFees`: Transfer accumulated fees to the fee recipient
- `pause`: Pause contract operations (owner only)
- `unpause`: Resume contract operations (owner only)
- `rescueToken`: Recover accidentally sent tokens (owner only)

### View Functions

- `getTotalReserves`: Get current reserves of both tokens
- `getTokenPair`: Retrieve addresses of the token pair
- `getPrice`: Get current exchange rate between the token pair

## Mathematical Foundations

The CPAMM is based on the constant product formula and related mathematical concepts. Here are the key formulas used in the implementation:

1. Constant Product Formula:
   ```
   xy = k
   ```
   Where x and y are the reserves of the two tokens, and k is a constant.

2. Swap Formula:
   ```
   ydx / (x + dx) = dy
   ```
   This formula determines the amount of output tokens (dy) for a given input (dx), maintaining the constant product.

3. Liquidity Value:
   ```
   f(x,y) = sqrt(xy)
   ```
   This represents the geometric mean of x and y, used to calculate the value of liquidity in the pool.

4. Liquidity Shares:
   ```
   s = dx / x * T = dy / y * T
   ```
   Where s is the number of shares minted or burned, dx and dy are the amounts of tokens added or removed, x and y are the current reserves, and T is the total supply of liquidity tokens.

These formulas form the mathematical foundation of the CPAMM, ensuring proper token exchange rates, liquidity provision, and removal while maintaining the constant product invariant.

## Security Considerations

Key security features include:

- ReentrancyGuard for all state-changing functions
- Slippage protection for trades and liquidity operations
- Pausable functionality for emergency situations
- Two-step process for critical operations to mitigate flash loan attacks

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contact

Deniz Umut Dereli - [GitHub](https://github.com/denizumutdereli)

Project Link: [https://github.com/denizumutdereli/enhanced-cpamm](https://github.com/denizumutdereli/enhanced-cpamm)