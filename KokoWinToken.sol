// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/// @notice Minimum interface for interacting with another TRC20 token.
interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract KokoWinToken {
    // ===== 1. Basic token information and states =====
    string public constant name = "KokoWin";
    string public constant symbol = "KOKO";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    address public owner;
    
    // Private contract message
    string private CONTRACT_MESSAGE = "Hello everyone! I want to leave my mark in the history of blockchain and AI development. My name is Misha. My friend Artem and I decided to create our own token, but we had no programming knowledge at all. To write the smart contract, we used ChatGPT. In just two weeks, we learned a lot of the basics and managed to create this contract. It turned out to be a truly fascinating journey. I don't know what benefits it might bring, but in the future, we will proudly tell the story of how we left our small imprint on this technology. Since a smart contract cannot be edited, and I am the one deploying it, I'd like to leave an important note for anyone reading it: My friend Artem M. is so henpecked), haha)!";
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ===== 2. Security and access modifiers =====
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    bool private locked;
    modifier nonReentrant() {
        require(!locked, "ReentrancyGuard: reentrant call");
        locked = true;
        _;
        locked = false;
    }
    
    bool public paused;
    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }
    
    // Variable controlling the initiation of new staking.
    // true - new stakes allowed, false - not allowed.
    bool public stakingEnabled = true;

    // ===== 3. Data structures =====
    struct LockedTokens {
        uint256 amount;
        uint256 unlockTime;
    }
    mapping(address => LockedTokens) public lockedTokens;
    
    struct Stake {
        uint256 amount;
        uint256 startTime;
        bool active;
    }
    // Each user can open one active stake per plan (ID: 1,2,3)
    mapping(address => mapping(uint8 => Stake)) public stakes;
    
    struct StakingPlan {
        uint256 annualRate;       // Annual interest rate
        uint256 withdrawalDelay;  // Withdrawal delay (in seconds)
    }
    mapping(uint8 => StakingPlan) public stakingPlans;
    
    // The MAX_STAKING_TIME parameter is used for reward calculation (maximum 180 days)
    uint256 public constant MAX_STAKING_TIME = 180 days;
    
    // Limit for airdrop – maximum 100 recipients
    uint256 public constant MAX_AIRDROP_RECIPIENTS = 100;
    
    // Variable for accumulating fees (3% of each transfer)
    uint256 public accumulatedFees;
    
    // ===== 4. Events =====
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Staked(address indexed user, uint8 planId, uint256 amount, uint256 startTime);
    event Unstaked(address indexed user, uint8 planId, uint256 principal, uint256 reward);
    event TokensLocked(address indexed user, uint256 amount, uint256 unlockTime);
    event LockedTokensClaimed(address indexed user, uint256 amount);
    event Airdrop(address indexed owner, uint256 totalAmount);
    event Burn(address indexed burner, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FeesClaimed(address indexed owner, uint256 amount);
    // Event for changing staking status
    event StakingStatusChanged(bool newStatus);
    
    // ===== 5. Constructor =====
    constructor() {
        owner = msg.sender;
        totalSupply = 1683117110 * (10 ** uint256(decimals));
        balanceOf[owner] = totalSupply;
        
        // Initialization of staking plans
        stakingPlans[1] = StakingPlan({ annualRate: 12, withdrawalDelay: 0 });
        stakingPlans[2] = StakingPlan({ annualRate: 24, withdrawalDelay: 60 days });
        stakingPlans[3] = StakingPlan({ annualRate: 35, withdrawalDelay: 90 days });
    }
    
    // ===== 6. Owner management and administrative functions =====
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    function pause() external onlyOwner {
        paused = true;
    }
    
    function unpause() external onlyOwner {
        paused = false;
    }
    
    // Function to control the initiation of new staking.
    // _status = true: new stakes allowed (start)
    // _status = false: new stakes disabled (stop)
    function setStakingStatus(bool _status) external onlyOwner {
        stakingEnabled = _status;
        emit StakingStatusChanged(_status);
    }
    
    // Function to check if staking (new stakes) is available
    function isStakingOpen() external view returns (bool) {
        return stakingEnabled;
    }
    
    // ===== 7. Internal utility functions =====
    function _transfer(address _from, address _to, uint256 _value, bool _applyCommission) internal whenNotPaused {
        require(_to != address(0), "Invalid address");
        uint256 senderBalance = balanceOf[_from];
        require(senderBalance >= _value, "Insufficient balance");
        
        if (_applyCommission && _from != owner && _to != owner) {
            // 2% is burned, 3% is added to accumulatedFees, the remainder goes to the recipient
            uint256 burnAmount = (_value * 2) / 100;
            uint256 fee = (_value * 3) / 100;
            uint256 transferAmount = _value - burnAmount - fee;
            
            balanceOf[_from] = senderBalance - _value;
            balanceOf[_to] += transferAmount;
            emit Transfer(_from, _to, transferAmount);
            
            accumulatedFees += fee;
            
            totalSupply -= burnAmount;
            emit Transfer(_from, address(0), burnAmount);
        } else {
            balanceOf[_from] = senderBalance - _value;
            balanceOf[_to] += _value;
            emit Transfer(_from, _to, _value);
        }
    }
    
    function _mintBonus(address _to, uint256 _reward) internal whenNotPaused {
        totalSupply += _reward;
        balanceOf[_to] += _reward;
        emit Transfer(address(0), _to, _reward);
    }
    
    // ===== 8. Standard TRC20 functions =====
    function transfer(address _to, uint256 _value) public whenNotPaused returns (bool) {
        _transfer(msg.sender, _to, _value, true);
        return true;
    }
    
    function approve(address _spender, uint256 _value) public returns (bool) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    
    function transferFrom(address _from, address _to, uint256 _value) public whenNotPaused returns (bool) {
        if (_from != msg.sender) {
            require(allowance[_from][msg.sender] >= _value, "Allowance exceeded");
            allowance[_from][msg.sender] -= _value;
        }
        _transfer(_from, _to, _value, true);
        return true;
    }
    
    // ===== 9. Staking functions =====
    // Each user can open one active stake per plan.
    // Until the user calls unstake() for a specific plan, they cannot open a new one for the same plan.
    // New stakes can be opened only if stakingEnabled == true.
    function stake(uint8 planId, uint256 _amount) public nonReentrant whenNotPaused {
        require(stakingEnabled, "Staking is currently disabled");
        require(planId >= 1 && planId <= 3, "Invalid staking plan");
        require(_amount > 0, "Cannot stake 0 tokens");
        require(balanceOf[msg.sender] >= _amount, "Insufficient balance");
        require(!stakes[msg.sender][planId].active, "Already staked in this plan");
        
        _transfer(msg.sender, address(this), _amount, false);
        
        stakes[msg.sender][planId] = Stake({
            amount: _amount,
            startTime: block.timestamp,
            active: true
        });
        
        emit Staked(msg.sender, planId, _amount, block.timestamp);
    }
    
    // The unstake() function returns the deposit and calculates the reward for the staking period.
    function unstake(uint8 planId) public nonReentrant whenNotPaused {
        require(planId >= 1 && planId <= 3, "Invalid staking plan");
        Stake storage userStake = stakes[msg.sender][planId];
        require(userStake.active, "No active stake for this plan");
        
        if (planId != 1) {
            require(block.timestamp - userStake.startTime >= stakingPlans[planId].withdrawalDelay, "Unstake not allowed before delay");
        }
        
        uint256 stakingDuration = block.timestamp - userStake.startTime;
        // Limit reward calculation time to MAX_STAKING_TIME (180 days)
        if (stakingDuration > MAX_STAKING_TIME) {
            stakingDuration = MAX_STAKING_TIME;
        }
        
        uint256 rate = stakingPlans[planId].annualRate;
        uint256 reward = (userStake.amount * rate * stakingDuration) / (365 days * 100);
        
        _mintBonus(msg.sender, reward);
        
        uint256 stakedAmountLocal = userStake.amount;
        userStake.amount = 0;
        userStake.active = false;
        
        _transfer(address(this), msg.sender, stakedAmountLocal, false);
        emit Unstaked(msg.sender, planId, stakedAmountLocal, reward);
    }
    
    // ===== 10. Token locking functions =====
    function lockTokens(uint256 _amount, uint256 _unlockTime) public whenNotPaused {
        require(_amount > 0, "Amount must be > 0");
        require(balanceOf[msg.sender] >= _amount, "Insufficient balance");
        require(_unlockTime > block.timestamp, "Unlock time must be in the future");
        require(lockedTokens[msg.sender].amount == 0, "You already have locked tokens");
        
        balanceOf[msg.sender] -= _amount;
        lockedTokens[msg.sender] = LockedTokens({
            amount: _amount,
            unlockTime: _unlockTime
        });
        emit TokensLocked(msg.sender, _amount, _unlockTime);
    }
    
    function claimLockedTokens() public nonReentrant whenNotPaused {
        LockedTokens storage lockInfo = lockedTokens[msg.sender];
        require(lockInfo.amount > 0, "No locked tokens");
        require(block.timestamp >= lockInfo.unlockTime, "Tokens are still locked");
        
        uint256 amount = lockInfo.amount;
        lockInfo.amount = 0;
        lockInfo.unlockTime = 0;
        balanceOf[msg.sender] += amount;
        emit LockedTokensClaimed(msg.sender, amount);
    }
    
    // ===== 11. Airdrop functions =====
    function airdropFromOwner(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner nonReentrant whenNotPaused {
        require(recipients.length == amounts.length, "Arrays must have the same length");
        require(recipients.length <= MAX_AIRDROP_RECIPIENTS, "Too many recipients");
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        require(balanceOf[msg.sender] >= totalAmount, "Not enough balance");
        for (uint256 i = 0; i < recipients.length; i++) {
            bool success = transferFrom(msg.sender, recipients[i], amounts[i]);
            require(success, "Transfer failed");
        }
        emit Airdrop(msg.sender, totalAmount);
    }
    
    // ===== 12. Token burning function =====
    function burn(uint256 _value) public nonReentrant whenNotPaused returns (bool) {
        require(balanceOf[msg.sender] >= _value, "Insufficient tokens");
        balanceOf[msg.sender] -= _value;
        totalSupply -= _value;
        emit Burn(msg.sender, _value);
        emit Transfer(msg.sender, address(0), _value);
        return true;
    }
    
    // ===== 13. Functions for handling native tokens (TRX) and fallback/receive =====
    receive() external payable {}
    fallback() external payable {}
    
    function withdrawTRX(uint256 amount) external onlyOwner nonReentrant whenNotPaused {
        require(amount <= address(this).balance, "Not enough TRX balance");
        payable(owner).transfer(amount);
    }
    
    function getTRXBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    // ===== 14. Functions for handling fees =====
    // On each transfer, a 3% fee is added to accumulatedFees.
    // The claimFees function allows the owner to withdraw a specified amount of fees,
    // and the getAccumulatedFees function returns the current balance of accumulated fees.
    function claimFees(uint256 amount) external onlyOwner nonReentrant whenNotPaused {
        require(amount <= accumulatedFees, "Not enough fees accumulated");
        accumulatedFees -= amount;
        balanceOf[owner] += amount;
        emit Transfer(address(this), owner, amount);
        emit FeesClaimed(owner, amount);
    }
    
    function getAccumulatedFees() external view returns (uint256) {
        return accumulatedFees;
    }
}
