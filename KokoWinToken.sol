// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/// @title KokoWinToken — Standard TRC20 token with staking, locking, airdrops, and TRX support
/// @notice Commission-free and fully compatible with CEX/DEX platforms

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract KokoWinToken {
    // ===== 1. Token metadata =====
    string public constant name = "KokoWin";
    string public constant symbol = "KOKO";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    address public owner;

    // Founder message (unchangeable, fun fact)
    string private CONTRACT_MESSAGE = "Hello everyone! I want to leave my mark in the history of blockchain and AI development. My name is Misha. My friend Artem and I decided to create our own token, but we had no programming knowledge at all. To write the smart contract, we used ChatGPT. In just two weeks, we learned a lot of the basics and managed to create this contract. It turned out to be a truly fascinating journey. I don't know what benefits it might bring, but in the future, we will proudly tell the story of how we left our small imprint on this technology. Since a smart contract cannot be edited, and I am the one deploying it, I'd like to leave an important note for anyone reading it: My friend Artem M. is so henpecked), haha)!";

    function getContractMessage() external view returns (string memory) {
        return CONTRACT_MESSAGE;
    }

    // ===== 2. Balances and allowances =====
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ===== 3. Security modifiers =====
    bool private locked;
    bool public paused;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    // ===== 4. Staking system =====
    bool public stakingEnabled = true;

    struct Stake {
        uint256 amount;
        uint256 startTime;
        bool active;
    }

    struct StakingPlan {
        uint256 annualRate;
        uint256 withdrawalDelay;
    }

    mapping(address => mapping(uint8 => Stake)) public stakes;
    mapping(uint8 => StakingPlan) public stakingPlans;
    uint256 public constant MAX_STAKING_TIME = 180 days;

    // ===== 5. Token locking =====
    struct LockedTokens {
        uint256 amount;
        uint256 unlockTime;
    }

    mapping(address => LockedTokens) public lockedTokens;

    // ===== 6. Airdrop config =====
    uint256 public constant MAX_AIRDROP_RECIPIENTS = 100;

    // ===== 7. Events =====
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Staked(address indexed user, uint8 planId, uint256 amount, uint256 startTime);
    event Unstaked(address indexed user, uint8 planId, uint256 principal, uint256 reward);
    event TokensLocked(address indexed user, uint256 amount, uint256 unlockTime);
    event LockedTokensClaimed(address indexed user, uint256 amount);
    event Airdrop(address indexed owner, uint256 totalAmount);
    event Burn(address indexed burner, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event StakingStatusChanged(bool newStatus);

    // ===== 8. Constructor =====
    constructor() {
        owner = msg.sender;
        totalSupply = 1683117110 * (10 ** uint256(decimals));
        balanceOf[owner] = totalSupply;

        // Initialize staking plans
        stakingPlans[1] = StakingPlan({ annualRate: 12, withdrawalDelay: 0 });
        stakingPlans[2] = StakingPlan({ annualRate: 24, withdrawalDelay: 60 days });
        stakingPlans[3] = StakingPlan({ annualRate: 35, withdrawalDelay: 90 days });
    }

    // ===== 9. Admin functions =====
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function pause() external onlyOwner {
        paused = true;
    }

    function unpause() external onlyOwner {
        paused = false;
    }

    function setStakingStatus(bool _status) external onlyOwner {
        stakingEnabled = _status;
        emit StakingStatusChanged(_status);
    }

    function isStakingOpen() external view returns (bool) {
        return stakingEnabled;
    }

    // ===== 10. Internal transfer logic =====
    function _transfer(address _from, address _to, uint256 _value) internal whenNotPaused {
        require(_to != address(0), "Invalid address");
        require(balanceOf[_from] >= _value, "Insufficient balance");

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(_from, _to, _value);
    }

    // ===== 11. TRC20 standard functions =====
    function transfer(address _to, uint256 _value) public whenNotPaused returns (bool) {
        _transfer(msg.sender, _to, _value);
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
        _transfer(_from, _to, _value);
        return true;
    }

    // ===== 12. Staking functions =====
    function stake(uint8 planId, uint256 _amount) public nonReentrant whenNotPaused {
        require(stakingEnabled, "Staking disabled");
        require(planId >= 1 && planId <= 3, "Invalid plan");
        require(_amount > 0, "Amount = 0");
        require(balanceOf[msg.sender] >= _amount, "Insufficient balance");
        require(!stakes[msg.sender][planId].active, "Already staked");

        _transfer(msg.sender, address(this), _amount);

        stakes[msg.sender][planId] = Stake({
            amount: _amount,
            startTime: block.timestamp,
            active: true
        });

        emit Staked(msg.sender, planId, _amount, block.timestamp);
    }

    function unstake(uint8 planId) public nonReentrant whenNotPaused {
        Stake storage userStake = stakes[msg.sender][planId];
        require(userStake.active, "No active stake");

        if (planId != 1) {
            require(block.timestamp - userStake.startTime >= stakingPlans[planId].withdrawalDelay, "Too early");
        }

        uint256 duration = block.timestamp - userStake.startTime;
        if (duration > MAX_STAKING_TIME) {
            duration = MAX_STAKING_TIME;
        }

        uint256 reward = (userStake.amount * stakingPlans[planId].annualRate * duration) / (365 days * 100);

        totalSupply += reward;
        balanceOf[msg.sender] += reward;
        emit Transfer(address(0), msg.sender, reward);

        uint256 principal = userStake.amount;
        userStake.amount = 0;
        userStake.active = false;

        _transfer(address(this), msg.sender, principal);
        emit Unstaked(msg.sender, planId, principal, reward);
    }

    // ===== 13. Token locking =====
    function lockTokens(uint256 _amount, uint256 _unlockTime) public whenNotPaused {
        require(_amount > 0, "Zero amount");
        require(balanceOf[msg.sender] >= _amount, "Insufficient");
        require(_unlockTime > block.timestamp, "Past unlock time");
        require(lockedTokens[msg.sender].amount == 0, "Already locked");

        balanceOf[msg.sender] -= _amount;
        lockedTokens[msg.sender] = LockedTokens({
            amount: _amount,
            unlockTime: _unlockTime
        });

        emit TokensLocked(msg.sender, _amount, _unlockTime);
    }

    function claimLockedTokens() public nonReentrant whenNotPaused {
        LockedTokens storage lockInfo = lockedTokens[msg.sender];
        require(lockInfo.amount > 0, "Nothing locked");
        require(block.timestamp >= lockInfo.unlockTime, "Still locked");

        uint256 amount = lockInfo.amount;
        lockInfo.amount = 0;
        lockInfo.unlockTime = 0;
        balanceOf[msg.sender] += amount;

        emit LockedTokensClaimed(msg.sender, amount);
    }

    // ===== 14. Airdrop function =====
    function airdropFromOwner(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner nonReentrant whenNotPaused {
        require(recipients.length == amounts.length, "Array mismatch");
        require(recipients.length <= MAX_AIRDROP_RECIPIENTS, "Too many recipients");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        require(balanceOf[msg.sender] >= totalAmount, "Insufficient balance");

        for (uint256 i = 0; i < recipients.length; i++) {
            transferFrom(msg.sender, recipients[i], amounts[i]);
        }

        emit Airdrop(msg.sender, totalAmount);
    }

    // ===== 15. Burn function =====
    function burn(uint256 _value) public nonReentrant whenNotPaused returns (bool) {
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");
        balanceOf[msg.sender] -= _value;
        totalSupply -= _value;

        emit Burn(msg.sender, _value);
        emit Transfer(msg.sender, address(0), _value);
        return true;
    }

    // ===== 16. TRX support =====
    receive() external payable {}
    fallback() external payable {}

    function withdrawTRX(uint256 amount) external onlyOwner nonReentrant whenNotPaused {
        require(amount <= address(this).balance, "Not enough TRX");
        payable(owner).transfer(amount);
    }

    function getTRXBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
