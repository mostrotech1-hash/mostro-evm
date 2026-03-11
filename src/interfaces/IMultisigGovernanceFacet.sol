// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IMultisigGovernanceFacet
/// @notice Public ABI for MultisigGovernanceFacet.
interface IMultisigGovernanceFacet {
    /// @dev Structure representing a proposal
    struct Proposal {
        uint256 id;                    // Unique proposal identifier
        address target;                // Target address for the call
        bytes data;                    // Call data (function signature + parameters)
        uint256 requiredApprovals;     // Number of required approvals
        uint256 approvalCount;         // Current approval count
        bool executed;                 // Execution status
        mapping(address => bool) approvers; // Tracking of signers who approved
    }
    
    function submitProposal(address target, bytes calldata data) 
    external returns (uint256);

    function approveProposal(uint256 proposalId) 
    external;

    function executeProposal(uint256 proposalId) 
    external;
}