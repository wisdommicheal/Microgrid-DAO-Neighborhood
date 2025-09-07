# Microgrid DAO - Neighborhood Solar Energy Distribution

A decentralized autonomous organization (DAO) smart contract for managing neighborhood-controlled solar energy distribution on the Stacks blockchain.

## Overview

The Microgrid DAO enables communities to collectively manage solar energy production, consumption, and trading within their neighborhood. Members can produce solar energy, consume from the shared pool, vote on energy policies, and trade energy directly with neighbors.

## Features

- **Member Management**: Join the DAO and track energy activities
- **Energy Production**: Record solar energy production with reputation rewards
- **Energy Consumption**: Consume energy from the shared neighborhood pool
- **Governance**: Create and vote on proposals for energy pricing and policies
- **Peer-to-Peer Trading**: Direct energy trading between neighbors
- **Reputation System**: Earn reputation through energy production and trading

## Smart Contract Functions

### Member Functions

#### `join-dao()`
Join the DAO as a new member with initial reputation score.

#### `get-member-info(member: principal)`
Retrieve member information including energy stats and reputation.

#### `is-member(address: principal)`
Check if an address is an active DAO member.

### Energy Management

#### `record-energy-production(amount: uint)`
Record solar energy production. Increases reputation and adds to energy pool.

#### `consume-energy(amount: uint)`
Consume energy from the shared pool. Must be an active member.

#### `get-member-energy-balance(member: principal)`
Get net energy balance (produced - consumed) for a member.

### Governance

#### `create-proposal(title, description, proposal-type, target-value)`
Create governance proposals for:
- `price-change`: Modify energy pricing
- `voting-period`: Change voting duration

#### `vote-on-proposal(proposal-id: uint, vote: bool)`
Vote on proposals using reputation-weighted voting power.

#### `execute-proposal(proposal-id: uint)`
Execute passed proposals after voting period ends.

### Energy Trading

#### `create-energy-trade(amount: uint, price: uint)`
List energy for sale to other members.

#### `buy-energy(trade-id: uint)`
Purchase energy from another member's trade listing.

#### `get-trade(trade-id: uint)`
View details of an energy trade.

## Usage Examples

### 1. Join the DAO
```clarity
(contract-call? .microgrid-dao join-dao)
```

### 2. Record Solar Energy Production
```clarity
(contract-call? .microgrid-dao record-energy-production u1000)
```

### 3. Create Energy Pricing Proposal
```clarity
(contract-call? .microgrid-dao create-proposal 
  "Lower Energy Price" 
  "Reduce price to 8 STX per unit" 
  "price-change" 
  u8)
```

### 4. Vote on Proposal
```clarity
(contract-call? .microgrid-dao vote-on-proposal u1 true)
```

### 5. Trade Energy
```clarity
;; Create trade listing
(contract-call? .microgrid-dao create-energy-trade u500 u12)

;; Buy energy
(contract-call? .microgrid-dao buy-energy u1)
```

## Error Codes

- `u100`: Unauthorized operation
- `u101`: Not a DAO member
- `u102`: Insufficient energy available
- `u103`: Invalid amount (must be > 0)
- `u104`: Proposal not found
- `u105`: Already voted on proposal
- `u106`: Voting period has ended
- `u107`: Proposal did not pass
- `u108`: Already a member

## Configuration

- **Initial Energy Price**: 10 STX per unit
- **Voting Period**: 1440 blocks (~10 days)
- **Minimum Reputation for Proposals**: 50 points
- **Initial Member Reputation**: 100 points

## Contract Parameters

- **Total Energy Pool**: Tracks community's available energy
- **Member Reputation**: Earned through production (10:1 ratio) and trading (+5)
- **Voting Power**: Proportional to member reputation score
- **Trade Completion**: Automatic reputation bonus for sellers

## Deployment

Deploy using Clarinet:

```bash
clarinet deploy --testnet
```

## Testing

Run contract tests:

```bash
clarinet test
```

## License

MIT License - Feel free to fork and adapt for your community's needs.
