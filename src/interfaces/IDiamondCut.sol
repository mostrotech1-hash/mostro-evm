// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDiamondCut {
    // Add    = wire new selectors to a facet
    // Replace = point existing selectors to a new facet
    // Remove  = delete selectors entirely
    enum FacetCutAction { Add, Replace, Remove }

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    /// @notice Add/replace/remove facet functions
    /// @param _diamondCut Array of FacetCut structs
    /// @param _init Address to delegatecall for initialisation (or address(0))
    /// @param _calldata Calldata for _init (or empty)
    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external;
}
