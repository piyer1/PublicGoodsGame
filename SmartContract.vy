#pragma version 0.4.0
# Public Goods Game Contract

# Structs
struct GameRound:
    active: bool
    totalStaked: uint256
    participantCount: uint256
    weightedVoteSum: uint256  # Sum of (vote * stake) for all participants
    totalVotes: uint256  # Sum of all votes (for calculating weighted average)
    endTime: uint256  # Timestamp when the round ends
    distributed: bool  # Whether funds have been distributed
    registrationPhase: bool  # Whether the round is in registration phase

# State variables
owner: public(address)
gameRounds: public(HashMap[uint256, GameRound])
currentRoundId: public(uint256)
roundDuration: public(uint256)  # Duration of each round in seconds
minStake: public(uint256)  # Minimum stake amount
gameCoinToEthRate: public(uint256)  # 1 GameCoin = 0.001 SepoliaETH (stored as 1000)
MIN_PARTICIPANTS: constant(uint256) = 3  # Minimum number of participants required

# Participant data
participantStakes: public(HashMap[uint256, HashMap[address, uint256]])  # roundId -> address -> stake
participantVotes: public(HashMap[uint256, HashMap[address, uint256]])  # roundId -> address -> vote (0-1000 scale)
hasParticipated: public(HashMap[uint256, HashMap[address, bool]])  # roundId -> address -> participated
participants: public(HashMap[uint256, DynArray[address, 100]])  # roundId -> participant addresses

# Events
event RoundRegistrationStarted:
    roundId: uint256
    startTime: uint256

event RoundStarted:
    roundId: uint256
    startTime: uint256
    endTime: uint256
    participantCount: uint256

event Registered:
    roundId: uint256
    participant: address
    amount: uint256

event Staked:
    roundId: uint256
    participant: address
    amount: uint256

event VoteCast:
    roundId: uint256
    participant: address
    vote: uint256  # 0-1000 scale (0 = 0%, 1000 = 100%)

event RoundEnded:
    roundId: uint256
    votingConstant: uint256  # 0-1000 scale
    totalStaked: uint256

event FundsDistributed:
    roundId: uint256
    recipient: address
    amount: uint256

event GameCoinRateChanged:
    newRate: uint256

# Initialize contract
@deploy
def __init__():
    self.owner = msg.sender
    self.currentRoundId = 0
    self.roundDuration = 86400  # 1 day in seconds
    self.minStake = 10 * 10**18  # 10 GameCoin minimum
    self.gameCoinToEthRate = 1000  # 1 GameCoin = 0.001 ETH

# Start registration phase for a new game round
@external
def startRegistrationPhase():
    assert msg.sender == self.owner, "Only owner can start registration"
    assert self.currentRoundId == 0 or not self.gameRounds[self.currentRoundId].active, "Current round still active"
    
    # If previous round exists, ensure it's been distributed
    if self.currentRoundId > 0:
        assert self.gameRounds[self.currentRoundId].distributed, "Previous round not distributed yet"
    
    roundId: uint256 = self.currentRoundId + 1
    self.currentRoundId = roundId
    
    # Set up new round in registration phase
    self.gameRounds[roundId] = GameRound({
        active: False,
        totalStaked: 0,
        participantCount: 0,
        weightedVoteSum: 0,
        totalVotes: 0,
        endTime: 0,  # Will be set when game actually starts
        distributed: False,
        registrationPhase: True
    })
    
    log RoundRegistrationStarted(roundId, block.timestamp)

# Register for the current round (during registration phase)
@payable
@external
def register():
    assert self.currentRoundId > 0, "No active registration"
    roundId: uint256 = self.currentRoundId
    assert self.gameRounds[roundId].registrationPhase, "Not in registration phase"
    assert not self.hasParticipated[roundId][msg.sender], "Already registered"
    
    # Convert ETH to GameCoin
    gameCoinAmount: uint256 = msg.value * self.gameCoinToEthRate
    assert gameCoinAmount >= self.minStake, "Stake below minimum"
    
    # Record participant
    self.hasParticipated[roundId][msg.sender] = True
    self.participantStakes[roundId][msg.sender] = gameCoinAmount
    self.participants[roundId].append(msg.sender)
    self.gameRounds[roundId].participantCount += 1
    self.gameRounds[roundId].totalStaked += gameCoinAmount
    
    log Registered(roundId, msg.sender, gameCoinAmount)

# Start the actual game round once minimum participants have registered
@external
def startRound():
    assert msg.sender == self.owner, "Only owner can start the round"
    assert self.currentRoundId > 0, "No round in registration phase"
    roundId: uint256 = self.currentRoundId
    assert self.gameRounds[roundId].registrationPhase, "Not in registration phase"
    assert self.gameRounds[roundId].participantCount >= MIN_PARTICIPANTS, "Need at least 3 participants"
    
    # Set end time and activate the round
    endTime: uint256 = block.timestamp + self.roundDuration
    self.gameRounds[roundId].endTime = endTime
    self.gameRounds[roundId].active = True
    self.gameRounds[roundId].registrationPhase = False
    
    log RoundStarted(roundId, block.timestamp, endTime, self.gameRounds[roundId].participantCount)

# Cast vote in the current round (after round has started)
@external
def castVote(vote: uint256):
    assert vote <= 1000, "Vote must be between 0 and 1000"
    assert self.currentRoundId > 0, "No active round"
    roundId: uint256 = self.currentRoundId
    assert self.gameRounds[roundId].active, "Round not active"
    assert not self.gameRounds[roundId].registrationPhase, "Still in registration phase"
    assert block.timestamp < self.gameRounds[roundId].endTime, "Round has ended"
    assert self.hasParticipated[roundId][msg.sender], "Not registered for this round"
    
    stake: uint256 = self.participantStakes[roundId][msg.sender]
    
    # Record vote
    self.participantVotes[roundId][msg.sender] = vote
    
    # Update round totals
    self.gameRounds[roundId].weightedVoteSum += vote * stake
    self.gameRounds[roundId].totalVotes += stake
    
    log VoteCast(roundId, msg.sender, vote)

# End the current round
@external
def endRound():
    assert self.currentRoundId > 0, "No active round"
    roundId: uint256 = self.currentRoundId
    assert self.gameRounds[roundId].active, "Round not active"
    assert block.timestamp >= self.gameRounds[roundId].endTime, "Round not yet ended"
    
    # Calculate voting constant (weighted average of votes)
    votingConstant: uint256 = 0
    if self.gameRounds[roundId].totalVotes > 0:
        votingConstant = self.gameRounds[roundId].weightedVoteSum / self.gameRounds[roundId].totalVotes
    
    # Mark round as ended
    self.gameRounds[roundId].active = False
    
    log RoundEnded(roundId, votingConstant, self.gameRounds[roundId].totalStaked)

# Distribute funds for a completed round
@external
def distributeFunds(roundId: uint256):
    assert msg.sender == self.owner, "Only owner can distribute funds"
    assert roundId > 0 and roundId <= self.currentRoundId, "Invalid round ID"
    assert not self.gameRounds[roundId].active, "Round still active"
    assert not self.gameRounds[roundId].registrationPhase, "Still in registration phase"
    assert not self.gameRounds[roundId].distributed, "Funds already distributed"
    
    # Calculate voting constant (weighted average)
    votingConstant: uint256 = 0
    if self.gameRounds[roundId].totalVotes > 0:
        votingConstant = self.gameRounds[roundId].weightedVoteSum / self.gameRounds[roundId].totalVotes
    
    totalStaked: uint256 = self.gameRounds[roundId].totalStaked
    participantCount: uint256 = self.gameRounds[roundId].participantCount
    
    # Amount to distribute proportionally (based on stakes)
    proportionalAmount: uint256 = totalStaked * votingConstant / 1000
    
    # Amount to distribute evenly
    evenAmount: uint256 = totalStaked - proportionalAmount
    amountPerParticipant: uint256 = 0
    if participantCount > 0:
        amountPerParticipant = evenAmount / participantCount
    
    # Mark as distributed
    self.gameRounds[roundId].distributed = True
    
    # Distribute to each participant
    for participant in self.participants[roundId]:
        stake: uint256 = self.participantStakes[roundId][participant]
        
        # Calculate proportional share
        proportionalShare: uint256 = 0
        if totalStaked > 0:
            proportionalShare = (stake * proportionalAmount) / totalStaked
        
        # Total amount to send
        amountToSend: uint256 = proportionalShare + amountPerParticipant
        
        # Convert GameCoin back to ETH
        ethAmount: uint256 = amountToSend / self.gameCoinToEthRate
        
        # Send the funds
        send(participant, ethAmount)
        log FundsDistributed(roundId, participant, amountToSend)

# Change the GameCoin to ETH rate (owner only)
@external
def changeGameCoinRate(newRate: uint256):
    assert msg.sender == self.owner, "Only owner can change rate"
    assert newRate > 0, "Rate must be positive"
    self.gameCoinToEthRate = newRate
    log GameCoinRateChanged(newRate)

# Change round duration (owner only)
@external
def changeRoundDuration(newDuration: uint256):
    assert msg.sender == self.owner, "Only owner can change duration"
    assert newDuration >= 3600, "Duration must be at least 1 hour"
    self.roundDuration = newDuration

# Change minimum stake (owner only)
@external
def changeMinStake(newMinStake: uint256):
    assert msg.sender == self.owner, "Only owner can change minimum stake"
    assert newMinStake > 0, "Minimum stake must be positive"
    self.minStake = newMinStake

# Get current round information
@view
@external
def getCurrentRoundInfo() -> (uint256, bool, bool, uint256, uint256, uint256, uint256):
    if self.currentRoundId == 0:
        return (0, False, False, 0, 0, 0, 0)
    
    roundId: uint256 = self.currentRoundId
    return (
        roundId,
        self.gameRounds[roundId].active,
        self.gameRounds[roundId].registrationPhase,
        self.gameRounds[roundId].totalStaked,
        self.gameRounds[roundId].participantCount,
        self.gameRounds[roundId].endTime,
        self._calculateVotingConstant(roundId)
    )

# Get participant information for a round
@view
@external
def getParticipantInfo(roundId: uint256, participant: address) -> (uint256, uint256, bool):
    return (
        self.participantStakes[roundId][participant],
        self.participantVotes[roundId][participant],
        self.hasParticipated[roundId][participant]
    )

# Helper function to calculate voting constant
@view
@internal
def _calculateVotingConstant(roundId: uint256) -> uint256:
    if self.gameRounds[roundId].totalVotes == 0:
        return 0
    return self.gameRounds[roundId].weightedVoteSum / self.gameRounds[roundId].totalVotes