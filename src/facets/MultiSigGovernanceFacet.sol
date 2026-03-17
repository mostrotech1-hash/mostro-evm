// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IMultisigGovernanceFacet} from "../interfaces/IMultisigGovernanceFacet.sol";
import {IMostroStructs} from "../interfaces/IMostroStructs.sol";
import {MultisigGovernanceStorage} from "../libraries/StorageLibraries.sol";

/**
 * @title MultisigGovernance
 * @dev Simple multi-signature governance contract allowing multiple signers
 * to collectively approve and execute proposals.
 */
contract MultisigGovernance is IMostroStructs, IMultisigGovernanceFacet {
    
    // ==================== Events ====================
    
    /// @dev Emitted when a new proposal is created
    event ProposalSubmitted(uint256 indexed proposalId, address indexed target, bytes data);
    
    /// @dev Emitted when a signer approves a proposal
    event ProposalApproved(uint256 indexed proposalId, address indexed signer, uint256 approvalsCount);
    
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
     * @dev Initializes the contract with signers and approval threshold
     * @param initialSigners Array of initial signer addresses
     * @param _quorum Number of approvals required to execute a proposal
     */
    constructor(address[] memory initialSigners, uint256 _quorum) {
        require(initialSigners.length > 0, "At least one signer is required");
        require(_quorum > 0 && _quorum <= initialSigners.length, 
                "Approval threshold must be between 1 and number of signers");
        
        // Add initial signers
        for (uint256 i = 0; i < initialSigners.length; i++) {
            address signer = initialSigners[i];
            require(signer != address(0), "Invalid signer address");
            require(!signers[signer], "Duplicate signer");
            
            signers[signer] = true;
            signersList.push(signer);
        }
        
        quorum = _quorum;
    }
    
    // ==================== Main Functions ====================
    
    /**
     * @dev Submits a new proposal
     * @param target Target address for the call
     * @param data Call data
     */
    function submitProposal(address target, bytes memory data) external {
        require(target != address(0), "Invalid target address");
        
        uint256 proposalId = proposalCount;
        
        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.target = target;
        newProposal.data = data;
        newProposal.requiredApprovals = quorum;
        newProposal.approvalCount = 0;
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
        onlySuperAdmin
        proposalExists(proposalId) 
        notExecuted(proposalId) 
    {
        if(!admins[msg.sender]) revert NotAnAdmin();
        Proposal storage proposal = proposals[proposalId];
        
        // Check that the signer has not already approved
        require(!proposal.approvers[msg.sender], "You have already approved this proposal");
        
        // Record the approval
        proposal.approvers[msg.sender] = true;
        proposal.approvalCount++;
        
        emit ProposalApproved(proposalId, msg.sender, proposal.approvalCount);
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