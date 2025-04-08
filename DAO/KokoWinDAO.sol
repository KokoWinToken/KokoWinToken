// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/// @title KokoWinToken Interface for DAO Voting
interface IKokoWinToken {
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

/// @title KokoWinDAO — Simple Decentralized Autonomous Organization
/// @notice Allows token holders to create proposals, vote, and execute decisions
contract KokoWinDAO {
    /// @notice Proposal structure
    struct Proposal {
        uint256 id;
        string description;
        address target;
        uint256 value;
        bytes callData;
        uint256 createdAt;
        uint256 votingDeadline;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
    }

    /// @notice Token interface used for voting
    IKokoWinToken public token;
    /// @notice Total number of proposals
    uint256 public proposalCount;
    /// @notice Voting period for each proposal (e.g., 7 days)
    uint256 public votingPeriod;
    /// @notice Minimum quorum required (e.g., 1% of total token supply)
    uint256 public quorumVotes;

    /// @notice Mapping of proposals by ID
    mapping(uint256 => Proposal) public proposals;
    /// @notice Tracks if an address has already voted on a proposal
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    /// @notice Simple reentrancy guard
    bool private locked;

    /// @notice Events
    event ProposalCreated(
        uint256 indexed proposalId,
        string description,
        address indexed target,
        uint256 value
    );
    event Voted(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 weight
    );
    event ProposalExecuted(uint256 indexed proposalId, bool success);

    /// @notice Reentrancy protection modifier
    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    /// @notice DAO constructor
    /// @param _tokenAddr Address of the KokoWinToken contract
    /// @param _votingPeriod Voting period in seconds
    /// @param _quorumPercentage Minimum quorum as a percentage (0–100), e.g. 1 = 1%
    constructor(address _tokenAddr, uint256 _votingPeriod, uint256 _quorumPercentage) {
        require(_tokenAddr != address(0), "Token address is zero");
        token = IKokoWinToken(_tokenAddr);
        votingPeriod = _votingPeriod;
        quorumVotes = token.totalSupply() * _quorumPercentage / 100;
    }

    /// @notice Creates a new proposal
    /// @dev Only token holders can create proposals
    /// @param _description Description of the proposal
    /// @param _target Address to call upon execution (optional)
    /// @param _value Amount of ETH to send with the call
    /// @param _callData Encoded function call data (if any)
    /// @return proposalId ID of the newly created proposal
    function createProposal(
        string memory _description,
        address _target,
        uint256 _value,
        bytes memory _callData
    ) external returns (uint256 proposalId) {
        require(token.balanceOf(msg.sender) > 0, "Not a token holder");

        proposalCount++;
        proposalId = proposalCount;

        Proposal memory newProposal = Proposal({
            id: proposalId,
            description: _description,
            target: _target,
            value: _value,
            callData: _callData,
            createdAt: block.timestamp,
            votingDeadline: block.timestamp + votingPeriod,
            forVotes: 0,
            againstVotes: 0,
            executed: false
        });

        proposals[proposalId] = newProposal;
        emit ProposalCreated(proposalId, _description, _target, _value);
    }

    /// @notice Vote on an active proposal
    /// @param _proposalId ID of the proposal
    /// @param _support true to vote "for", false to vote "against"
    function vote(uint256 _proposalId, bool _support) external {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp <= proposal.votingDeadline, "Voting period ended");
        require(!hasVoted[_proposalId][msg.sender], "Already voted");

        uint256 voteWeight = token.balanceOf(msg.sender);
        require(voteWeight > 0, "No voting power");

        if (_support) {
            proposal.forVotes += voteWeight;
        } else {
            proposal.againstVotes += voteWeight;
        }

        hasVoted[_proposalId][msg.sender] = true;
        emit Voted(_proposalId, msg.sender, _support, voteWeight);
    }

    /// @notice Execute a proposal if approved and quorum met
    /// @dev Requires majority approval and minimum quorum
    /// @param _proposalId ID of the proposal to execute
    function executeProposal(uint256 _proposalId) external nonReentrant {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp > proposal.votingDeadline, "Voting still active");
        require(!proposal.executed, "Already executed");
        require(
            (proposal.forVotes + proposal.againstVotes) >= quorumVotes,
            "Quorum not met"
        );
        require(proposal.forVotes > proposal.againstVotes, "Not approved");

        proposal.executed = true;
        (bool success, ) = proposal.target.call{value: proposal.value}(proposal.callData);
        require(success, "Execution failed");

        emit ProposalExecuted(_proposalId, success);
    }

    /// @notice Returns the full proposal struct
    /// @param _proposalId ID of the proposal
    /// @return Proposal data
    function getProposal(uint256 _proposalId) external view returns (Proposal memory) {
        return proposals[_proposalId];
    }

    /// @notice Allows DAO to receive ETH (used for execution with value)
    receive() external payable {}
    fallback() external payable {}
}
