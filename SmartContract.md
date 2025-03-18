# Public Goods Game Smart Contract Documentation

## Overview

This smart contract implements a public goods game where users can stake GameCoin, vote on a redistribution mechanism, and receive rewards based on a weighted voting system. The contract manages the complete lifecycle of game rounds including registration, staking, voting, and redistribution.

## Key Concepts

- **GameCoin**: An in-game currency with a fixed exchange rate of 1 GameCoin = 0.001 SepoliaETH.
- **Round States**: Each round progresses through defined states: Registration → Started → Staking → Voting → Redistribution → Completed.
- **Voting Constant**: A number between 0 and 1 (represented as 0-1000 internally) that determines how funds are redistributed:
  - `votingConstant` portion of the pool is distributed proportionally to stakes
  - `1 - votingConstant` portion is distributed evenly among all participants

## Contract Functions

### Setup and Configuration

#### `__init__()`
- **Description**: Constructor function that initializes the contract.
- **Called by**: Automatically executed on contract deployment.
- **Actions**: Sets the contract owner, initializes the first round.

### User Operations

#### `purchaseGameCoin()`
- **Description**: Converts Sepolia ETH to GameCoin at the exchange rate of 1:1000.
- **Parameters**: None (ETH value is sent with the transaction).
- **Returns**: None.
- **Requirements**:
  - Cannot be called during an active round if the user is already registered.
- **Example Usage**:
  ```javascript
  await contract.purchaseGameCoin({ value: ethers.utils.parseEther("0.01") });
  ```

#### `register()`
- **Description**: Registers the user for the current round.
- **Parameters**: None.
- **Returns**: None.
- **Requirements**:
  - No round is currently active.
  - User is not already registered.
  - User has a GameCoin balance greater than zero.
- **Example Usage**:
  ```javascript
  await contract.register();
  ```

#### `startRound()`
- **Description**: Signals that the user is ready to start the round. Round begins when all registered users call this function.
- **Parameters**: None.
- **Returns**: None.
- **Requirements**:
  - No round is currently active.
  - User is registered for the round.
  - At least MIN_USERS (2) users are registered.
- **Example Usage**:
  ```javascript
  await contract.startRound();
  ```

#### `stake(amount)`
- **Description**: Stakes GameCoin from the user's balance into the round's pool.
- **Parameters**:
  - `amount` (uint256): Amount of GameCoin to stake.
- **Returns**: None.
- **Requirements**:
  - Round is active and in the staking state.
  - User is registered and has not already staked.
  - User has sufficient GameCoin balance.
- **Example Usage**:
  ```javascript
  await contract.stake(1000); // Stake 1000 GameCoin
  ```

#### `vote(voteValue)`
- **Description**: Votes on the redistribution mechanism. Value represents the portion of the pool that should be distributed proportionally.
- **Parameters**:
  - `voteValue` (uint256): Number between 0 and 1000, representing 0-1 (e.g., 750 = 0.75).
- **Returns**: None.
- **Requirements**:
  - Round is active and in the voting state.
  - User is registered, has staked, and has not already voted.
- **Example Usage**:
  ```javascript
  await contract.vote(750); // Vote for 75% proportional distribution
  ```

#### `redistribute()`
- **Description**: Signals that the user is ready for redistribution. When all users call this function, funds are redistributed.
- **Parameters**: None.
- **Returns**: None.
- **Requirements**:
  - Round is active and in the redistribution state.
  - User is registered, has voted, and has not already called redistribution.
- **Example Usage**:
  ```javascript
  await contract.redistribute();
  ```

### View Functions

#### `getGameCoinBalance(user)`
- **Description**: Gets the GameCoin balance of a user.
- **Parameters**:
  - `user` (address): Address of the user to check.
- **Returns**: uint256 - The user's GameCoin balance.
- **Example Usage**:
  ```javascript
  const balance = await contract.getGameCoinBalance(userAddress);
  ```

#### `getRoundInfo(id)`
- **Description**: Gets information about a specific round.
- **Parameters**:
  - `id` (uint256): Round ID to query.
- **Returns**: Tuple containing:
  1. State of the round (uint8)
  2. User count (uint256)
  3. Total pool size (uint256)
  4. Voting constant (uint256)
  5. Number of participants (uint256)
- **Example Usage**:
  ```javascript
  const roundInfo = await contract.getRoundInfo(1);
  ```

#### `getUserInfo(user)`
- **Description**: Gets information about a specific user.
- **Parameters**:
  - `user` (address): Address of the user to check.
- **Returns**: Tuple containing:
  1. Registration status (bool)
  2. Stake status (bool)
  3. Vote status (bool)
  4. GameCoin balance (uint256)
  5. Staked amount (uint256)
- **Example Usage**:
  ```javascript
  const userInfo = await contract.getUserInfo(userAddress);
  ```

#### `getEthToGameCoinRate()`
- **Description**: Gets the conversion rate from ETH to GameCoin.
- **Parameters**: None.
- **Returns**: uint256 - The conversion rate (1000).
- **Example Usage**:
  ```javascript
  const rate = await contract.getEthToGameCoinRate();
  ```

#### `owner()`
- **Description**: Gets the address of the contract owner.
- **Parameters**: None.
- **Returns**: address - The owner's address.
- **Example Usage**:
  ```javascript
  const ownerAddress = await contract.owner();
  ```

#### `roundId()`
- **Description**: Gets the current round ID.
- **Parameters**: None.
- **Returns**: uint256 - The current round ID.
- **Example Usage**:
  ```javascript
  const currentRoundId = await contract.roundId();
  ```

#### `isRoundActive()`
- **Description**: Checks if a round is currently active.
- **Parameters**: None.
- **Returns**: bool - True if a round is active, false otherwise.
- **Example Usage**:
  ```javascript
  const active = await contract.isRoundActive();
  ```

### Admin Operations

#### `emergencyCompleteRound()`
- **Description**: Forcefully completes a round in case of emergency.
- **Parameters**: None.
- **Returns**: None.
- **Requirements**:
  - Caller is the contract owner.
  - A round is currently active.
- **Example Usage**:
  ```javascript
  await contract.emergencyCompleteRound();
  ```

## Game Flow and Usage

### Complete Game Cycle:

1. **Initial Setup**:
   - Users convert ETH to GameCoin using `purchaseGameCoin()`.
   ```javascript
   await contract.purchaseGameCoin({ value: ethers.utils.parseEther("0.01") });
   ```

2. **Registration Phase**:
   - Users register for the round using `register()`.
   ```javascript
   await contract.register();
   ```

3. **Round Start**:
   - Each registered user signals readiness using `startRound()`.
   - When all registered users have called this function, the round state advances to Staking.
   ```javascript
   await contract.startRound();
   ```

4. **Staking Phase**:
   - Users stake GameCoin into the pool using `stake(amount)`.
   - When all users have staked, the round state advances to Voting.
   ```javascript
   await contract.stake(500); // Stake 500 GameCoin
   ```

5. **Voting Phase**:
   - Users vote on the redistribution mechanism using `vote(voteValue)`.
   - When all users have voted, the voting constant is computed and the round state advances to Redistribution.
   ```javascript
   await contract.vote(750); // Vote for 75% proportional distribution
   ```

6. **Redistribution Phase**:
   - Users signal readiness for redistribution using `redistribute()`.
   - When all users have called this function, funds are redistributed according to the voting constant.
   - The round is completed and a new round is prepared.
   ```javascript
   await contract.redistribute();
   ```

7. **Check Results**:
   - Users can check their GameCoin balance after redistribution.
   ```javascript
   const balance = await contract.getGameCoinBalance(userAddress);
   ```

## Key Events

The contract emits the following events that can be monitored:

- `GameCoinPurchased`: When a user converts ETH to GameCoin.
- `UserRegistered`: When a user registers for a round.
- `RoundStarted`: When all users have signaled readiness and the round begins.
- `UserStaked`: When a user stakes GameCoin into the pool.
- `UserVoted`: When a user votes on the redistribution mechanism.
- `VotingConstantComputed`: When all users have voted and the voting constant is calculated.
- `FundsRedistributed`: When funds are redistributed from the pool.
- `RoundCompleted`: When a round is completed.

## Constants

- `CONVERSION_RATE`: 1000 (1 GameCoin = 0.001 SepoliaETH)
- `MIN_USERS`: 2 (Minimum users required to start a round)
- `MAX_USERS`: 50 (Maximum users allowed in a game)

## Round States

- `REGISTRATION` (0): Initial state where users can register.
- `STARTED` (1): All users have signaled readiness.
- `STAKING` (2): Users are staking GameCoin into the pool.
- `VOTING` (3): Users are voting on the redistribution mechanism.
- `REDISTRIBUTION` (4): Funds are being redistributed.
- `COMPLETED` (5): Round is completed.