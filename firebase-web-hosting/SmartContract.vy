# Public Goods Game with GameCoin, staking, weighted voting, and redistribution

# Constants
CONVERSION_RATE: constant(uint256) = 1000  # 1 GameCoin = 0.001 SepoliaETH
MIN_USERS: constant(uint256) = 2  # Minimum users to start a game
MAX_USERS: constant(uint256) = 50  # Maximum users in a game

# Round states
REGISTRATION: constant(uint8) = 0
STARTED: constant(uint8) = 1
STAKING: constant(uint8) = 2
VOTING: constant(uint8) = 3
REDISTRIBUTION: constant(uint8) = 4
COMPLETED: constant(uint8) = 5

# Events
event GameCoinPurchased:
    user: indexed(address)
    ethAmount: uint256
    gameCoinAmount: uint256

event UserRegistered:
    user: indexed(address)
    roundId: indexed(uint256)

event RoundStarted:
    roundId: indexed(uint256)
    userCount: uint256

event UserStaked:
    user: indexed(address)
    roundId: indexed(uint256)
    amount: uint256

event UserVoted:
    user: indexed(address)
    roundId: indexed(uint256)
    vote: uint256  # Scaled by 1000 (0-1000 representing 0-1)

event VotingConstantComputed:
    roundId: indexed(uint256)
    votingConstant: uint256  # Scaled by 1000

event FundsRedistributed:
    roundId: indexed(uint256)
    totalPool: uint256
    proportionalAmount: uint256
    evenSplitAmount: uint256

event RoundCompleted:
    roundId: indexed(uint256)

# Struct definitions
struct User:
    registered: bool
    staked: bool
    voted: bool
    redistributionCalled: bool
    balance: uint256  # User's GameCoin balance
    stakedAmount: uint256  # Amount staked in current round
    vote: uint256  # User's vote (0-1000 representing 0-1)

struct Round:
    state: uint8
    userCount: uint256
    usersStarted: uint256
    usersStaked: uint256
    usersVoted: uint256
    usersRedistributed: uint256
    totalPool: uint256
    votingConstant: uint256  # Scaled by 1000 (0-1000 representing 0-1)
    participants: DynArray[address, MAX_USERS]

# State variables
owner: public(address)
roundId: public(uint256)
users: public(HashMap[address, User])
rounds: public(HashMap[uint256, Round])
isRoundActive: public(bool)

# Initialize contract
@payable
@deploy
def __init__():
    self.owner = msg.sender
    self.roundId = 0
    self.isRoundActive = False
    # Initialize first round
    self._initializeRound(0)

# Internal: Initialize a new round
@internal
def _initializeRound(id: uint256):
    self.rounds[id] = Round({
        state: REGISTRATION,
        userCount: 0,
        usersStarted: 0,
        usersStaked: 0,
        usersVoted: 0,
        usersRedistributed: 0,
        totalPool: 0,
        votingConstant: 0,
        participants: []
    })

# Purchase GameCoin with specified ETH amount
@payable
@external
def purchaseGameCoin(ethAmount: uint256):
    assert not (self.isRoundActive and self.users[msg.sender].registered), "Cannot purchase during active round"
    assert msg.value == ethAmount, "Sent ETH does not match specified amount"
    
    gameCoinAmount: uint256 = ethAmount * CONVERSION_RATE
    
    # Add GameCoin to user's balance
    self.users[msg.sender].balance += gameCoinAmount

    assert self.users[msg.sender].balance >= gameCoinAmount, "Transaction was unsuccessful"
    
    log GameCoinPurchased(msg.sender, ethAmount, gameCoinAmount)

# Register for the current round
@external
def register():
    assert not self.isRoundActive, "A round is already active"
    assert not self.users[msg.sender].registered, "Already registered"
    assert self.users[msg.sender].balance > 0, "Must have GameCoin to register"
    
    currentRound: Round = self.rounds[self.roundId]
    assert currentRound.userCount < MAX_USERS, "Maximum users reached"
    
    # Register user
    self.users[msg.sender].registered = True
    self.users[msg.sender].staked = False
    self.users[msg.sender].voted = False
    self.users[msg.sender].redistributionCalled = False
    self.users[msg.sender].stakedAmount = 0
    self.users[msg.sender].vote = 0
    
    # Update round
    currentRound.userCount += 1
    currentRound.participants.append(msg.sender)
    self.rounds[self.roundId] = currentRound
    
    log UserRegistered(msg.sender, self.roundId)

# Start the round (must be called by each registered user)
@external
def startRound():
    assert not self.isRoundActive, "Round already started"
    assert self.users[msg.sender].registered, "Not registered for this round"
    
    currentRound: Round = self.rounds[self.roundId]
    assert currentRound.userCount >= MIN_USERS, "Not enough users registered"
    assert currentRound.state == REGISTRATION, "Not in registration state"
    
    # Mark user as started
    currentRound.usersStarted += 1
    
    # If all users have started, transition to staking phase
    if currentRound.usersStarted == currentRound.userCount:
        currentRound.state = STAKING
        self.isRoundActive = True
        log RoundStarted(self.roundId, currentRound.userCount)
    
    self.rounds[self.roundId] = currentRound

# Stake GameCoin into the pool
@external
def stake(amount: uint256):
    assert self.isRoundActive, "No active round"
    assert self.users[msg.sender].registered, "Not registered for this round"
    assert not self.users[msg.sender].staked, "Already staked"
    
    currentRound: Round = self.rounds[self.roundId]
    assert currentRound.state == STAKING, "Not in staking state"
    assert amount <= self.users[msg.sender].balance, "Insufficient balance"
    
    # Process stake
    self.users[msg.sender].stakedAmount = amount
    self.users[msg.sender].balance -= amount
    self.users[msg.sender].staked = True
    
    currentRound.totalPool += amount
    currentRound.usersStaked += 1
    
    # If all users have staked, transition to voting phase
    if currentRound.usersStaked == currentRound.userCount:
        currentRound.state = VOTING
    
    self.rounds[self.roundId] = currentRound
    log UserStaked(msg.sender, self.roundId, amount)

# Vote on the redistribution mechanism (0-1000 representing 0-1)
@external
def vote(voteValue: uint256):
    assert self.isRoundActive, "No active round"
    assert self.users[msg.sender].registered, "Not registered for this round"
    assert self.users[msg.sender].staked, "Must stake before voting"
    assert not self.users[msg.sender].voted, "Already voted"
    assert voteValue <= 1000, "Vote must be between 0 and 1000"
    
    currentRound: Round = self.rounds[self.roundId]
    assert currentRound.state == VOTING, "Not in voting state"
    
    # Record vote
    self.users[msg.sender].vote = voteValue
    self.users[msg.sender].voted = True
    
    currentRound.usersVoted += 1
    
    # If all users have voted, compute the voting constant
    if currentRound.usersVoted == currentRound.userCount:
        # Compute weighted average of votes
        totalWeight: uint256 = 0
        weightedSum: uint256 = 0
        
        for i: uint256 in range(MAX_USERS):
            if i >= len(currentRound.participants):
                break
                
            participant: address = currentRound.participants[i]
            weight: uint256 = self.users[participant].stakedAmount
            vote: uint256 = self.users[participant].vote
            
            if weight > 0:  # Only count users who staked
                totalWeight += weight
                weightedSum += weight * vote
        
        # Set voting constant (weighted average)
        if totalWeight > 0:
            currentRound.votingConstant = weightedSum // totalWeight
        else:
            currentRound.votingConstant = 500  # Default to 0.5 if no one staked
            
        currentRound.state = REDISTRIBUTION
        log VotingConstantComputed(self.roundId, currentRound.votingConstant)
    
    self.rounds[self.roundId] = currentRound
    log UserVoted(msg.sender, self.roundId, voteValue)

# Request redistribution (must be called by each user)
@external
def redistribute():
    assert self.isRoundActive, "No active round"
    assert self.users[msg.sender].registered, "Not registered for this round"
    assert self.users[msg.sender].voted, "Must vote before redistribution"
    assert not self.users[msg.sender].redistributionCalled, "Already called redistribution"
    
    currentRound: Round = self.rounds[self.roundId]
    assert currentRound.state == REDISTRIBUTION, "Not in redistribution state"
    
    # Mark user as requested redistribution
    self.users[msg.sender].redistributionCalled = True
    currentRound.usersRedistributed += 1
    
    # If all users have requested redistribution, perform the redistribution
    if currentRound.usersRedistributed == currentRound.userCount:
        self._performRedistribution(currentRound)
        
        # Reset for next round
        self._completeRound()
    
    self.rounds[self.roundId] = currentRound

# Internal: Perform redistribution of the pool
@internal
def _performRedistribution(currentRound: Round):
    totalPool: uint256 = currentRound.totalPool
    votingConstant: uint256 = currentRound.votingConstant  # 0-1000
    
    # Calculate the proportional and even split amounts
    proportionalAmount: uint256 = totalPool * votingConstant // 1000
    evenSplitAmount: uint256 = totalPool - proportionalAmount
    
    # If there are active participants, distribute funds
    if currentRound.userCount > 0:
        # Even split per user
        evenSplitPerUser: uint256 = 0
        if evenSplitAmount > 0:
            evenSplitPerUser = evenSplitAmount // currentRound.userCount
        
        # Distribute to each user
        for i: uint256 in range(MAX_USERS):
            if i >= len(currentRound.participants):
                break
                
            participant: address = currentRound.participants[i]
            user: User = self.users[participant]
            
            # Even split portion
            userAmount: uint256 = evenSplitPerUser
            
            # Proportional portion based on stake
            if proportionalAmount > 0 and currentRound.totalPool > 0:
                proportionalShare: uint256 = (user.stakedAmount * proportionalAmount) // currentRound.totalPool
                userAmount += proportionalShare
                
            # Add funds to user balance
            self.users[participant].balance += userAmount
            
            # Reset user for next round
            self.users[participant].stakedAmount = 0
    
    log FundsRedistributed(self.roundId, totalPool, proportionalAmount, evenSplitAmount)

# Internal: Complete the current round and prepare for the next
@internal
def _completeRound():
    currentRound: Round = self.rounds[self.roundId]
    
    # Reset participants for the next round
    for i: uint256 in range(MAX_USERS):
        if i >= len(currentRound.participants):
            break
            
        participant: address = currentRound.participants[i]
        self.users[participant].registered = False
        self.users[participant].staked = False
        self.users[participant].voted = False
        self.users[participant].redistributionCalled = False
    
    log RoundCompleted(self.roundId)
    
    # Prepare for next round
    self.roundId += 1
    self._initializeRound(self.roundId)
    self.isRoundActive = False

# View functions
@view
@external
def getGameCoinBalance() -> uint256:
    return self.users[msg.sender].balance // 1000000000000000000

@view
@external
def getRoundInfo(id: uint256) -> (uint8, uint256, uint256, uint256, uint256):
    round: Round = self.rounds[id]
    return (
        round.state,
        round.userCount,
        round.totalPool,
        round.votingConstant,
        len(round.participants)
    )

@view
@external
def getUserInfo(user: address) -> (bool, bool, bool, uint256, uint256):
    user_data: User = self.users[user]
    return (
        user_data.registered,
        user_data.staked,
        user_data.voted,
        user_data.balance,
        user_data.stakedAmount
    )

@view
@external
def getEthToGameCoinRate() -> uint256:
    return CONVERSION_RATE

# Emergency functions (owner only)
@external
def emergencyCompleteRound():
    assert msg.sender == self.owner, "Owner only"
    assert self.isRoundActive, "No active round"
    
    # Force complete the round
    self._completeRound()