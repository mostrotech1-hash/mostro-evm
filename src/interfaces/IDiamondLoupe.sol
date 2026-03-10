// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDiamondLoupe {
    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    /// @notice Returns all facets and their selectors
    function facets() external view returns (Facet[] memory facets_);

    /// @notice Returns all selectors for a given facet address
    function facetFunctionSelectors(address _facet)
    external view returns (bytes4[] memory);

    /// @notice Returns all facet addresses
    function facetAddresses()
    external view returns (address[] memory);

    /// @notice Returns the facet address for a given selector
    function facetAddress(bytes4 _functionSelector)
    external view returns (address);
}
