// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
* @title Vote system
* @author Jordan Hereng
*/
contract Voting is Ownable(msg.sender) {
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

    mapping (address => Voter) private whitelist;
    uint private voterCount;

    mapping (uint => Proposal) public proposals;
    uint private proposalCount;

    uint private winnerProposal;

    WorkflowStatus private currentStatus;

    constructor() {
        currentStatus = WorkflowStatus.RegisteringVoters;
    }

    event VoterRegistered(address voterAddress);
    event WorkflowStatusChanged(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    /**
    * @notice Vérifie si l'utilisateur est enregistré
    */
    modifier isRegistered() {
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

    function StartProposalsRegistration() external onlyOwner {
        require(currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposals registration has already started");
        require(currentStatus > WorkflowStatus.RegisteringVoters, "Proposals registration is no longer possible");
        require(voterCount > 0, "Need more voters to start proposals registration");

        currentStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChanged(WorkflowStatus.RegisteringVoters, currentStatus);
    }

    function EndProposalsRegistration() external onlyOwner {
        require(currentStatus < WorkflowStatus.ProposalsRegistrationStarted, "Proposals registration has not started yet");
        require(currentStatus == WorkflowStatus.ProposalsRegistrationEnded, "Proposals registration has already ended");
        require(currentStatus > WorkflowStatus.ProposalsRegistrationEnded, "Proposals registration is already passed");
        require(proposalCount > 0, "Need more proposals to stop proposals registration");

        currentStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChanged(WorkflowStatus.ProposalsRegistrationStarted, currentStatus);
    }

    function StartVotingSession() external onlyOwner {
        require(currentStatus < WorkflowStatus.ProposalsRegistrationEnded, "Need more steps before starting voting session");
        require(currentStatus == WorkflowStatus.VotingSessionStarted, "Voting session has already started");
        require(currentStatus > WorkflowStatus.VotingSessionStarted, "Start voting session is no longer possible");
        
        currentStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChanged(WorkflowStatus.ProposalsRegistrationEnded, currentStatus);
    }

    function EndVotingSession() external onlyOwner {
        require(currentStatus < WorkflowStatus.VotingSessionStarted, "Voting session has not started yet");
        require(currentStatus == WorkflowStatus.VotingSessionEnded, "Voting session has already ended");
        require(currentStatus > WorkflowStatus.VotingSessionEnded, "Voting session is already passed");
        
        currentStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChanged(WorkflowStatus.VotingSessionStarted, currentStatus);
    }

    function CountVotes() external onlyOwner {
        require(currentStatus < WorkflowStatus.VotingSessionEnded, "Need more steps before counting votes");
        require(currentStatus == WorkflowStatus.VotesTallied, "Votes are already counted");

        currentStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChanged(WorkflowStatus.VotingSessionEnded, currentStatus);
    }

    /**
    * @notice Enregistre une proposition
    * @param description Intitulé de la proposition
    */
    function registerProposal(string calldata description) external isRegistered {
        require(currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "Can't register any proposal for the moment");

        Proposal memory proposal;
        proposal.description = description;
        proposal.voteCount = 0;

        proposals[proposalCount + 1] = proposal;

        emit ProposalRegistered(proposalCount + 1);
        proposalCount++;
    }

    /**
    * @notice Prend un compte le vote d'un utilisateur pour une proposition
    * @param proposalId Identifiant de la proposition
    */
    function vote(uint proposalId) external isRegistered {
        require(currentStatus == WorkflowStatus.VotingSessionStarted, "Can't vote for the moment");
        require(!whitelist[msg.sender].hasVoted, "You already voted for this vote session");

        proposals[proposalId].voteCount++;
        whitelist[msg.sender].hasVoted = true;
        whitelist[msg.sender].votedProposalId = proposalId;

        if (proposals[proposalId].voteCount > proposals[winnerProposal].voteCount) {
            winnerProposal = proposalId;
        }

        emit Voted(msg.sender, proposalId);
    }

    /**
    * @return Proposition gagnante
    */
    function getWinner() external view returns (Proposal memory) {
        require(currentStatus == WorkflowStatus.VotesTallied, "Can't get the winner for the moment");
        require(winnerProposal != 0, "No vote has been registered");
        return proposals[winnerProposal];
    }
}
