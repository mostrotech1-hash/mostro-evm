// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MostroRoleManagerFacet} from "./facets/MostroRoleManagerFacet.sol";

/**
 * @title MultisigGovernance
 * @dev Multi-signature governance contract for Mostro
 */
 
contract MultisigGovernance {

    // ==================== Structs =====================

    /// @dev Structure representing a proposal
    struct Proposal {
        uint256 id;                    // Unique proposal identifier
        address target;                // Target address for the call
        bytes data;                    // Call data (function signature + parameters)
        uint256 approvalThreshold;     // Weight threshold for execution
        uint256 approvalWeight;         // Current approval weight
        bool executed;                 // Execution status
        mapping(address => bool) approvers; // Tracking of signers who approved
    }

    // ==================== Variables =====================

    uint256 proposalCount;
    address public immutable DiamondContract;
    mapping(uint256 => Proposal) proposals;
    mapping(address => bool) signers;
    address[] signersList;
    
    // ==================== Events ====================
    
    /// @dev Emitted when linked contract address is updated
    event DiamondUpdated(address indexed diamondContract);

    /// @dev Emitted when a new proposal is created
    event ProposalSubmitted(uint256 indexed proposalId, address indexed target, bytes data);
    
    /// @dev Emitted when a signer approves a proposal
    event ProposalApproved(uint256 indexed proposalId, address indexed signer, uint256 approvalWeight);
    
    /// @dev Emitted when a proposal is executed
    event ProposalExecuted(uint256 indexed proposalId, bool success, bytes result);
    
    // ==================== Modifiers ====================
    
    /// @dev Verifies that the proposal exists
    modifier proposalExists(uint256 proposalId) {
        require(proposalId < proposalCount, "Proposal does not exist");
        _;
    }
    
    /// @dev Verifies that the proposal has not already been executed
    modifier notExecuted(uint256 proposalId) {
        require(!proposals[proposalId].executed, "Proposal has already been executed");
        _;
    }
    
    // ==================== Constructor ====================
    
    /**
     * @dev Initializes the contract Deployed RoleManager contract address linked at deployment time
     */
    constructor(address _diamondContract) {
        
        DiamondContract = _diamondContract;
        emit DiamondUpdated(DiamondContract);

    }
    
    // ==================== Main Functions ====================
    
    /**
     * @dev Submits a new proposal
     * @param target Target address for the call
     * @param data Call data
     * @param approvalThreshold Approval weight required to execute the proposal
     */
    function submitProposal(address target, bytes memory data, uint256 approvalThreshold) external {
        require(target != address(0), "Invalid target address");
        
        uint256 proposalId = proposalCount;
        
        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.target = target;
        newProposal.data = data;
        newProposal.approvalThreshold = approvalThreshold;
        newProposal.approvalWeight = 0;
        newProposal.executed = false;
        
        proposalCount++;
        
        emit ProposalSubmitted(proposalId, target, data);
    }
    
    /**
     * @dev Approves a proposal
     * @param proposalId Proposal identifier to approve
     */
    function approveProposal(uint256 proposalId) 
        external 
        proposalExists(proposalId) 
        notExecuted(proposalId) 
    {
        require(MostroRoleManagerFacet(DiamondContract).isSuperAdmin(msg.sender) == true ||
                MostroRoleManagerFacet(DiamondContract).isAdmin(msg.sender) == true,
            "The msg sender must have the admin or the super admin role"
        );

        Proposal storage proposal = proposals[proposalId];
        
        // Check that the signer has not already approved
        require(!proposal.approvers[msg.sender], "You have already approved this proposal");
        
        // Record the approval
        proposal.approvers[msg.sender] = true;

        if(MostroRoleManagerFacet(DiamondContract).isSuperAdmin(msg.sender)) {
            proposal.approvalWeight += 2; // Super admin approvals count as 2
        } else {
            proposal.approvalWeight += 1; // Regular admin approvals count as 1
        }
        
        emit ProposalApproved(proposalId, msg.sender, proposal.approvalWeight);
    }
    
    /**
     * @dev Executes a proposal if the approval threshold is reached
     * @param proposalId Proposal identifier to execute
     */
    function executeProposal(uint256 proposalId) 
        external 
        proposalExists(proposalId) 
        notExecuted(proposalId) 
    {
        Proposal storage proposal = proposals[proposalId];
        
        // Check that the approval threshold is reached
        require(
            proposal.approvalWeight >= proposal.approvalThreshold,
            "Insufficient approval weight to execute this proposal"
        );
        
        // Mark as executed before the call (reentrancy protection)
        proposal.executed = true;
        
        // Execute the call
        (bool success, bytes memory result) = proposal.target.call(proposal.data);
        
        emit ProposalExecuted(proposalId, success, result);
        
        require(success, "Proposal execution failed");
    }
    
    // ==================== Query Functions ====================
    
    /**
     * @dev Returns the details of a proposal
     * @param proposalId Proposal identifier
     */
    function getProposal(uint256 proposalId) 
        external 
        view 
        proposalExists(proposalId) 
        returns (
            uint256 id,
            address target,
            bytes memory data,
            uint256 approvalThreshold,
            uint256 approvalWeight,
            bool executed
        ) 
    {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.target,
            proposal.data,
            proposal.approvalThreshold,
            proposal.approvalWeight,
            proposal.executed
        );
    }
    
    /**
     * @dev Checks if an address has approved a proposal
     * @param proposalId Proposal identifier
     * @param signer Signer address
     */
    function hasApproved(uint256 proposalId, address signer) 
        external 
        view 
        proposalExists(proposalId) 
        returns (bool) 
    {
        return proposals[proposalId].approvers[signer];
    }
}