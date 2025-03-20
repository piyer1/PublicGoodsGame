console.log("Ethers loaded:", typeof ethers !== 'undefined' ? ethers.version : 'not loaded');
console.log("Ethers providers:", ethers.providers);
// GameCoin Public Goods Game - Main JavaScript
document.addEventListener('DOMContentLoaded', function() {
    // Contract ABI - Generated from Vyper contract
    const contractABI = [
        {
            "name": "GameCoinPurchased",
            "type": "event",
            "inputs": [
                {"name": "user", "type": "address", "indexed": true},
                {"name": "ethAmount", "type": "uint256", "indexed": false},
                {"name": "gameCoinAmount", "type": "uint256", "indexed": false}
            ]
        },
        {
            "name": "UserRegistered",
            "type": "event",
            "inputs": [
                {"name": "user", "type": "address", "indexed": true},
                {"name": "roundId", "type": "uint256", "indexed": true}
            ]
        },
        {
            "name": "RoundStarted",
            "type": "event",
            "inputs": [
                {"name": "roundId", "type": "uint256", "indexed": true},
                {"name": "userCount", "type": "uint256", "indexed": false}
            ]
        },
        {
            "name": "UserStaked",
            "type": "event",
            "inputs": [
                {"name": "user", "type": "address", "indexed": true},
                {"name": "roundId", "type": "uint256", "indexed": true},
                {"name": "amount", "type": "uint256", "indexed": false}
            ]
        },
        {
            "name": "UserVoted",
            "type": "event",
            "inputs": [
                {"name": "user", "type": "address", "indexed": true},
                {"name": "roundId", "type": "uint256", "indexed": true},
                {"name": "vote", "type": "uint256", "indexed": false}
            ]
        },
        {
            "name": "VotingConstantComputed",
            "type": "event",
            "inputs": [
                {"name": "roundId", "type": "uint256", "indexed": true},
                {"name": "votingConstant", "type": "uint256", "indexed": false}
            ]
        },
        {
            "name": "FundsRedistributed",
            "type": "event",
            "inputs": [
                {"name": "roundId", "type": "uint256", "indexed": true},
                {"name": "totalPool", "type": "uint256", "indexed": false},
                {"name": "proportionalAmount", "type": "uint256", "indexed": false},
                {"name": "evenSplitAmount", "type": "uint256", "indexed": false}
            ]
        },
        {
            "name": "RoundCompleted",
            "type": "event",
            "inputs": [
                {"name": "roundId", "type": "uint256", "indexed": true}
            ]
        },
        {
            "name": "purchaseGameCoin",
            "type": "function",
            "stateMutability": "payable",
            "inputs": [{"name": "ethAmount", "type": "uint256"}],
            "outputs": []
        },
        {
            "name": "register",
            "type": "function",
            "stateMutability": "nonpayable",
            "inputs": [],
            "outputs": []
        },
        {
            "name": "startRound",
            "type": "function",
            "stateMutability": "nonpayable",
            "inputs": [],
            "outputs": []
        },
        {
            "name": "stake",
            "type": "function",
            "stateMutability": "nonpayable",
            "inputs": [{"name": "amount", "type": "uint256"}],
            "outputs": []
        },
        {
            "name": "vote",
            "type": "function",
            "stateMutability": "nonpayable",
            "inputs": [{"name": "voteValue", "type": "uint256"}],
            "outputs": []
        },
        {
            "name": "redistribute",
            "type": "function",
            "stateMutability": "nonpayable",
            "inputs": [],
            "outputs": []
        },
        {
            "name": "getGameCoinBalance",
            "type": "function",
            "stateMutability": "view",
            "inputs": [],
            "outputs": [{"name": "", "type": "uint256"}]
        },
        {
            "name": "getRoundInfo",
            "type": "function",
            "stateMutability": "view",
            "inputs": [{"name": "id", "type": "uint256"}],
            "outputs": [
                {"name": "", "type": "uint8"},
                {"name": "", "type": "uint256"},
                {"name": "", "type": "uint256"},
                {"name": "", "type": "uint256"},
                {"name": "", "type": "uint256"}
            ]
        },
        {
            "name": "getUserInfo",
            "type": "function",
            "stateMutability": "view",
            "inputs": [{"name": "user", "type": "address"}],
            "outputs": [
                {"name": "", "type": "bool"},
                {"name": "", "type": "bool"},
                {"name": "", "type": "bool"},
                {"name": "", "type": "uint256"},
                {"name": "", "type": "uint256"}
            ]
        },
        {
            "name": "getEthToGameCoinRate",
            "type": "function",
            "stateMutability": "view",
            "inputs": [],
            "outputs": [{"name": "", "type": "uint256"}]
        },
        {
            "name": "roundId",
            "type": "function",
            "stateMutability": "view",
            "inputs": [],
            "outputs": [{"name": "", "type": "uint256"}]
        },
        {
            "name": "isRoundActive",
            "type": "function",
            "stateMutability": "view",
            "inputs": [],
            "outputs": [{"name": "", "type": "bool"}]
        }
    ];

    // Contract address
    const contractAddress = "0x0b1c9208759427d8560985dfe0e3202af131594a";

    // State variables
    let provider, signer, contract;
    let userAddress = null;
    let userGameCoinBalance = 0;
    let currentRoundId = 0;
    let roundState = 0;
    let isRoundActive = false;

    // DOM Elements
    const connectWalletBtn = document.getElementById('connectWalletBtn');
    const walletInfo = document.getElementById('walletInfo');
    const walletNotConnected = document.getElementById('walletNotConnected');
    const gameInterface = document.getElementById('gameInterface');
    const roundStateDisplay = document.getElementById('roundStateDisplay');
    
    // Purchase elements
    const purchaseAmount = document.getElementById('purchaseAmount');
    const purchaseBtn = document.getElementById('purchaseBtn');
    const purchaseStatus = document.getElementById('purchaseStatus');
    
    // Game action elements
    const registerBtn = document.getElementById('registerBtn');
    const startRoundBtn = document.getElementById('startRoundBtn');
    const stakeAmount = document.getElementById('stakeAmount');
    const stakeBtn = document.getElementById('stakeBtn');
    const voteValue = document.getElementById('voteValue');
    const voteBtn = document.getElementById('voteBtn');
    const redistributeBtn = document.getElementById('redistributeBtn');

    // Status elements
    const registerStatus = document.getElementById('registerStatus');
    const startRoundStatus = document.getElementById('startRoundStatus');
    const stakeStatus = document.getElementById('stakeStatus');
    const voteStatus = document.getElementById('voteStatus');
    const redistributeStatus = document.getElementById('redistributeStatus');

    // Round info elements
    const roundId = document.getElementById('roundId');
    const roundStateInfo = document.getElementById('roundState');
    const userCount = document.getElementById('userCount');
    const totalPool = document.getElementById('totalPool');
    const votingConstant = document.getElementById('votingConstant');
    const userStatus = document.getElementById('userStatus');

    // Tab navigation
    const tabs = document.querySelectorAll('.tab');
    const tabContents = document.querySelectorAll('.tab-content');

    // Constants
    const roundStateLabels = [
        "Registration",
        "Started",
        "Staking",
        "Voting",
        "Redistribution",
        "Completed"
    ];

    // Initialize the application
    async function initApp() {
        setupEventListeners();
        await checkWalletConnection();
    }

    // Set up event listeners
    function setupEventListeners() {
        connectWalletBtn.addEventListener('click', connectWallet);
        purchaseBtn.addEventListener('click', purchaseGameCoin);
        registerBtn.addEventListener('click', registerForRound);
        startRoundBtn.addEventListener('click', startRound);
        stakeBtn.addEventListener('click', stakeGameCoin);
        voteBtn.addEventListener('click', submitVote);
        redistributeBtn.addEventListener('click', redistributeFunds);

        // Tab navigation
        tabs.forEach(tab => {
            tab.addEventListener('click', () => {
                // Remove active class from all tabs
                tabs.forEach(t => t.classList.remove('active'));
                
                // Add active class to clicked tab
                tab.classList.add('active');
                
                // Hide all tab contents
                tabContents.forEach(content => content.classList.add('hidden'));
                
                // Show selected tab content
                const tabId = tab.getAttribute('data-tab');
                document.getElementById(`${tabId}Tab`).classList.remove('hidden');
            });
        });
    }

    // Check if wallet is already connected
    async function checkWalletConnection() {
        if (window.ethereum) {
            provider = new ethers.providers.Web3Provider(window.ethereum);
            
            try {
                // Check if we're already connected
                const accounts = await provider.listAccounts();
                if (accounts.length > 0) {
                    await onWalletConnected(accounts[0]);
                }
            } catch (error) {
                console.error("Error checking wallet connection:", error);
            }
        } else {
            showStatus(purchaseStatus, "Web3 wallet not detected. Please install MetaMask.", "error");
        }
    }

    // Connect wallet
    async function connectWallet() {
        if (window.ethereum) {
            try {
                connectWalletBtn.disabled = true;
                connectWalletBtn.innerHTML = 'Connecting... <span class="loader"></span>';
                
                provider = new ethers.providers.Web3Provider(window.ethereum);
                
                // Request account access
                const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
                await onWalletConnected(accounts[0]);
                
                connectWalletBtn.disabled = false;
                connectWalletBtn.textContent = 'Wallet Connected';
            } catch (error) {
                console.error("Error connecting wallet:", error);
                showStatus(purchaseStatus, "Error connecting wallet. Please try again.", "error");
                connectWalletBtn.disabled = false;
                connectWalletBtn.textContent = 'Connect Wallet';
            }
        } else {
            showStatus(purchaseStatus, "Web3 wallet not detected. Please install MetaMask.", "error");
        }
    }

    // After wallet is connected
    async function onWalletConnected(account) {
        userAddress = account;
        signer = provider.getSigner();
        contract = new ethers.Contract(contractAddress, contractABI, signer);
        
        // Setup event listeners for wallet changes
        window.ethereum.on('accountsChanged', handleAccountsChanged);
        window.ethereum.on('chainChanged', () => window.location.reload());
        
        // Update UI
        walletNotConnected.classList.add('hidden');
        gameInterface.classList.remove('hidden');
        
        // Display wallet info
        const shortenedAddress = `${account.substring(0, 6)}...${account.substring(account.length - 4)}`;
        walletInfo.innerHTML = `
            <div class="address">Address: ${shortenedAddress}</div>
            <div class="balances">
                <div>GameCoin: <span id="gameCoinBalance">Loading...</span></div>
                <div>ETH: <span id="ethBalance">Loading...</span></div>
            </div>
        `;
        
        // Refresh game data
        await refreshGameData();
        
        // Setup interval for periodic updates
        setInterval(refreshGameData, 10000); // Refresh every 10 seconds
    }

    // Handle account change in MetaMask
    async function handleAccountsChanged(accounts) {
        if (accounts.length === 0) {
            // User disconnected their wallet
            window.location.reload();
        } else {
            // User switched accounts
            userAddress = accounts[0];
            signer = provider.getSigner();
            contract = new ethers.Contract(contractAddress, contractABI, signer);
            await refreshGameData();
        }
    }

    // Purchase GameCoin with ETH
    async function purchaseGameCoin() {
        try {
            const amount = purchaseAmount.value;
            if (!amount || amount <= 0) {
                showStatus(purchaseStatus, "Please enter a valid amount.", "error");
                return;
            }
            
            const ethAmountWei = ethers.utils.parseEther(amount);
            
            purchaseBtn.disabled = true;
            purchaseBtn.innerHTML = 'Processing... <span class="loader"></span>';
            showStatus(purchaseStatus, "Transaction in progress...", "warning");
            
            const tx = await contract.purchaseGameCoin(ethAmountWei, { value: ethAmountWei });
            
            showStatus(purchaseStatus, "Transaction submitted. Waiting for confirmation...", "warning");
            
            const receipt = await tx.wait();
            
            if (receipt.status === 1) {
                showStatus(purchaseStatus, `Successfully purchased GameCoin!`, "success");
                await refreshGameData();
            } else {
                showStatus(purchaseStatus, "Transaction failed. Please try again.", "error");
            }
        } catch (error) {
            console.error("Error purchasing GameCoin:", error);
            showStatus(purchaseStatus, `Error: ${parseError(error)}`, "error");
        } finally {
            purchaseBtn.disabled = false;
            purchaseBtn.textContent = 'Purchase GameCoin';
        }
    }

    // Register for round
    async function registerForRound() {
        try {
            registerBtn.disabled = true;
            registerBtn.innerHTML = 'Registering... <span class="loader"></span>';
            showStatus(registerStatus, "Transaction in progress...", "warning");
            
            const tx = await contract.register();
            
            showStatus(registerStatus, "Registration submitted. Waiting for confirmation...", "warning");
            
            const receipt = await tx.wait();
            
            if (receipt.status === 1) {
                showStatus(registerStatus, "Successfully registered for round!", "success");
                await refreshGameData();
            } else {
                showStatus(registerStatus, "Registration failed. Please try again.", "error");
            }
        } catch (error) {
            console.error("Error registering for round:", error);
            showStatus(registerStatus, `Error: ${parseError(error)}`, "error");
        } finally {
            registerBtn.disabled = false;
            registerBtn.textContent = 'Register for Round';
        }
    }

    // Start round
    async function startRound() {
        try {
            startRoundBtn.disabled = true;
            startRoundBtn.innerHTML = 'Starting... <span class="loader"></span>';
            showStatus(startRoundStatus, "Transaction in progress...", "warning");
            
            const tx = await contract.startRound();
            
            showStatus(startRoundStatus, "Start round submitted. Waiting for confirmation...", "warning");
            
            const receipt = await tx.wait();
            
            if (receipt.status === 1) {
                showStatus(startRoundStatus, "Successfully started round!", "success");
                await refreshGameData();
            } else {
                showStatus(startRoundStatus, "Start round failed. Please try again.", "error");
            }
        } catch (error) {
            console.error("Error starting round:", error);
            showStatus(startRoundStatus, `Error: ${parseError(error)}`, "error");
        } finally {
            startRoundBtn.disabled = false;
            startRoundBtn.textContent = 'Start Round';
        }
    }

    // Stake GameCoin
    async function stakeGameCoin() {
        try {
            const amount = stakeAmount.value;
            if (!amount || amount <= 0) {
                showStatus(stakeStatus, "Please enter a valid amount.", "error");
                return;
            }
            
            const stakeAmountBN = ethers.BigNumber.from(amount);
            
            stakeBtn.disabled = true;
            stakeBtn.innerHTML = 'Staking... <span class="loader"></span>';
            showStatus(stakeStatus, "Transaction in progress...", "warning");
            
            const tx = await contract.stake(stakeAmountBN);
            
            showStatus(stakeStatus, "Stake submitted. Waiting for confirmation...", "warning");
            
            const receipt = await tx.wait();
            
            if (receipt.status === 1) {
                showStatus(stakeStatus, `Successfully staked ${amount} GameCoin!`, "success");
                await refreshGameData();
            } else {
                showStatus(stakeStatus, "Staking failed. Please try again.", "error");
            }
        } catch (error) {
            console.error("Error staking GameCoin:", error);
            showStatus(stakeStatus, `Error: ${parseError(error)}`, "error");
        } finally {
            stakeBtn.disabled = false;
            stakeBtn.textContent = 'Stake GameCoin';
        }
    }

    // Submit vote
    async function submitVote() {
        try {
            const vote = voteValue.value;
            if (!vote || vote < 0 || vote > 1000) {
                showStatus(voteStatus, "Please enter a valid vote between 0 and 1000.", "error");
                return;
            }
            
            const voteBN = ethers.BigNumber.from(vote);
            
            voteBtn.disabled = true;
            voteBtn.innerHTML = 'Voting... <span class="loader"></span>';
            showStatus(voteStatus, "Transaction in progress...", "warning");
            
            const tx = await contract.vote(voteBN);
            
            showStatus(voteStatus, "Vote submitted. Waiting for confirmation...", "warning");
            
            const receipt = await tx.wait();
            
            if (receipt.status === 1) {
                showStatus(voteStatus, `Successfully voted ${vote/10}%!`, "success");
                await refreshGameData();
            } else {
                showStatus(voteStatus, "Voting failed. Please try again.", "error");
            }
        } catch (error) {
            console.error("Error submitting vote:", error);
            showStatus(voteStatus, `Error: ${parseError(error)}`, "error");
        } finally {
            voteBtn.disabled = false;
            voteBtn.textContent = 'Submit Vote';
        }
    }

    // Redistribute funds
    async function redistributeFunds() {
        try {
            redistributeBtn.disabled = true;
            redistributeBtn.innerHTML = 'Redistributing... <span class="loader"></span>';
            showStatus(redistributeStatus, "Transaction in progress...", "warning");
            
            const tx = await contract.redistribute();
            
            showStatus(redistributeStatus, "Redistribution submitted. Waiting for confirmation...", "warning");
            
            const receipt = await tx.wait();
            
            if (receipt.status === 1) {
                showStatus(redistributeStatus, "Successfully called redistribution!", "success");
                await refreshGameData();
            } else {
                showStatus(redistributeStatus, "Redistribution failed. Please try again.", "error");
            }
        } catch (error) {
            console.error("Error redistributing funds:", error);
            showStatus(redistributeStatus, `Error: ${parseError(error)}`, "error");
        } finally {
            redistributeBtn.disabled = false;
            redistributeBtn.textContent = 'Redistribute Funds';
        }
    }

    // Refresh game data
    async function refreshGameData() {
        if (!userAddress || !contract) return;
        
        try {
            // Get ETH balance
            const ethBalance = await provider.getBalance(userAddress);
            const ethBalanceFormatted = parseFloat(ethers.utils.formatEther(ethBalance)).toFixed(4);
            
            // Get GameCoin balance
            const gcBalance = await contract.getGameCoinBalance();
            userGameCoinBalance = gcBalance.toString();
            
            // Get current round info
            currentRoundId = await contract.roundId();
            isRoundActive = await contract.isRoundActive();
            
            const roundInfo = await contract.getRoundInfo(currentRoundId);
            roundState = roundInfo[0];
            const usersCount = roundInfo[1].toString();
            const poolTotal = roundInfo[2].toString();
            const voteConstant = roundInfo[3].toString();
            
            // Get user info for current round
            const userInfo = await contract.getUserInfo(userAddress);
            const isRegistered = userInfo[0];
            const hasStaked = userInfo[1];
            const hasVoted = userInfo[2];
            
            // Update UI elements
            document.getElementById('gameCoinBalance').textContent = userGameCoinBalance;
            document.getElementById('ethBalance').textContent = ethBalanceFormatted;
            
            roundId.textContent = currentRoundId.toString();
            roundStateInfo.textContent = roundStateLabels[roundState];
            userCount.textContent = usersCount;
            totalPool.textContent = poolTotal;
            votingConstant.textContent = voteConstant === '0' ? '-' : `${(voteConstant / 10).toFixed(1)}%`;
            
            // Update round state display
            roundStateDisplay.textContent = `Round State: ${roundStateLabels[roundState]}`;
            
            // Update user status
            let statusText = "";
            if (isRegistered) {
                statusText += "Registered ✓ ";
                if (hasStaked) {
                    statusText += "Staked ✓ ";
                    if (hasVoted) {
                        statusText += "Voted ✓";
                    } else {
                        statusText += "Need to Vote";
                    }
                } else {
                    statusText += "Need to Stake";
                }
            } else {
                statusText = "Not Registered";
            }
            userStatus.textContent = statusText;
            
            // Enable/disable buttons based on state
            updateButtonStates(roundState, isRegistered, hasStaked, hasVoted, isRoundActive);
            
        } catch (error) {
            console.error("Error refreshing game data:", error);
        }
    }

    // Update button states based on current game state
    function updateButtonStates(state, isRegistered, hasStaked, hasVoted, isActive) {
        // Purchase button is disabled during active round if registered
        purchaseBtn.disabled = isActive && isRegistered;
        
        // Register button is enabled only during registration phase and when not registered
        registerBtn.disabled = isActive || isRegistered;
        
        // Start round button is enabled only after registration and before round starts
        startRoundBtn.disabled = state !== 0 || !isRegistered || isActive;
        
        // Stake button is enabled only during staking phase and when not staked
        stakeBtn.disabled = state !== 2 || !isRegistered || hasStaked || !isActive;
        
        // Vote button is enabled only during voting phase and when staked but not voted
        voteBtn.disabled = state !== 3 || !isRegistered || !hasStaked || hasVoted || !isActive;
        
        // Redistribute button is enabled only during redistribution phase and when voted
        redistributeBtn.disabled = state !== 4 || !isRegistered || !hasVoted || !isActive;
    }

    // Show status message
    function showStatus(element, message, type) {
        element.textContent = message;
        element.className = `status ${type}`;
        
        // Clear success messages after 5 seconds
        if (type === "success") {
            setTimeout(() => {
                if (element.classList.contains("success")) {
                    element.textContent = "";
                    element.className = "";
                }
            }, 5000);
        }
    }

    // Parse error messages from blockchain
    function parseError(error) {
        // Check for specific error messages from the contract
        if (error.message && error.message.includes("execution reverted:")) {
            const errorMessage = error.message.split("execution reverted:")[1].trim();
            return errorMessage.replace(/"/g, '');
        }
        
        // Handle common MetaMask errors
        if (error.code) {
            switch (error.code) {
                case 4001:
                    return "Transaction rejected by user";
                case -32603:
                    if (error.message && error.message.includes("insufficient funds")) {
                        return "Insufficient funds for transaction";
                    }
            }
        }
        
        return "Transaction failed";
    }

    // Initialize the app when document is loaded
    initApp();
});