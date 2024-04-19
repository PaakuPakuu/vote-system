// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";

struct Voter {
    bool isRegistered;
    bool hasVoted;
    uint votedProposalId;
}

struct Proposal {
    string description;
    uint voteCount;
}

enum WorkflowStatus {
    RegisteringVoters,
    ProposalsRegistrationStarted,
    ProposalsRegistrationEnded,
    VotingSessionStarted,
    VotingSessionEnded,
    VotesTallied
}

/**
* @title Vote system
* @author Jordan Hereng
*/
contract Voting is Ownable(msg.sender) {
    mapping (address => Voter) private whitelist;
    uint private voterCount;

    mapping (uint => Proposal) private proposals;
    uint private proposalCount;

    uint private winnerProposal;

    WorkflowStatus private currentStatus;

    constructor() {
        currentStatus = WorkflowStatus.RegisteringVoters;
    }

    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    /**
    * @notice Vérifie si l'utilisateur est enregistré
    */
    modifier isWhitelisted() {
        require(whitelist[msg.sender].isRegistered, "Not authorized");
        _;
    }

    /**
    *
    *
    */
    function registerVoter(address voterAddress) external onlyOwner {
        require(currentStatus == WorkflowStatus.RegisteringVoters);
        require(!whitelist[voterAddress].isRegistered, "Already registered");

        Voter memory voter;
        voter.isRegistered = true;
        voter.hasVoted = false;
        whitelist[voterAddress] = voter;
        voterCount++;
        
        emit VoterRegistered(voterAddress);
    }

    /**
    * @notice Passe à l'étape suivant si possible
    */
    function takeNextStep() external onlyOwner {
        if (currentStatus == WorkflowStatus.RegisteringVoters && voterCount == 0) {
            revert("Need more voters to take the next step");
        }

        if (currentStatus == WorkflowStatus.ProposalsRegistrationStarted && proposalCount == 0) {
            revert("Need more proposals to take the next step");
        }

        if (currentStatus == WorkflowStatus.VotesTallied) {
            revert("Can't go further");
        }
        
        WorkflowStatus previousStatus = currentStatus;
        currentStatus = WorkflowStatus(uint(currentStatus) + 1);

        emit WorkflowStatusChange(previousStatus, currentStatus);
    }

    /**
    * @notice Enregistre une proposition
    * @param description Description de la proposition
    */
    function registerProposal(string calldata description) external isWhitelisted {
        require(currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "Can't register any proposal for the moment");

        Proposal memory proposal;
        proposal.description = description;
        proposal.voteCount = 0;

        proposals[proposalCount] = proposal;

        emit ProposalRegistered(proposalCount);
        proposalCount++;
    }

    /**
    * @notice Prend un compte le vote d'un utilisateur pour une proposition
    * @param proposalId Identifiant de la proposition
    */
    function vote(uint proposalId) external isWhitelisted {
        require(currentStatus == WorkflowStatus.VotingSessionStarted, "Can't vote for the moment");
        require(!whitelist[msg.sender].hasVoted, "You already voted for this vote session");

        proposals[proposalId].voteCount++;
        whitelist[msg.sender].hasVoted = true;
        whitelist[msg.sender].votedProposalId = proposalId;

        if (proposalCount == 0 || proposals[proposalId].voteCount > proposals[winnerProposal].voteCount) {
            winnerProposal = proposalId;
        }

        emit Voted(msg.sender, proposalId);
    }

    /**
    * @return Proposition gagnante
    */
    function getWinner() external view returns (Proposal memory) {
        require(currentStatus == WorkflowStatus.VotesTallied, "Can't get the winner for the moment");
        return proposals[winnerProposal];
    }
}
