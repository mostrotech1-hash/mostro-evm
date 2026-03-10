// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IDiamondCut} from "../interfaces/IDiamondCut.sol";

library LibDiamond {

    // -------------------------------------------------------------------------
    // Storage
    // -------------------------------------------------------------------------

    bytes32 constant DIAMOND_STORAGE_POSITION =
        keccak256("diamond.standard.diamond.storage");

    struct FacetAddressAndPosition {
        address facetAddress;
        uint96 functionSelectorPosition; // position in facetFunctionSelectors array
    }

    struct DiamondStorage {
        // selector => facet address + position
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        // facet address => all selectors it owns
        mapping(address => bytes4[]) facetFunctionSelectors;
        // all registered facet addresses (for enumeration)
        address[] facetAddresses;
        // ERC165 supported interfaces
        mapping(bytes4 => bool) supportedInterfaces;
        // owner
        address contractOwner;
    }

    function diamondStorage()
        internal
        pure
        returns (DiamondStorage storage ds)
    {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    // -------------------------------------------------------------------------
    // Ownership
    // -------------------------------------------------------------------------

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    function setContractOwner(address _newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        address previous = ds.contractOwner;
        ds.contractOwner = _newOwner;
        emit OwnershipTransferred(previous, _newOwner);
    }

    function contractOwner() internal view returns (address) {
        return diamondStorage().contractOwner;
    }

    function enforceIsContractOwner() internal view {
        require(
            msg.sender == diamondStorage().contractOwner,
            "LibDiamond: Not owner"
        );
    }

    // -------------------------------------------------------------------------
    // DiamondCut
    // -------------------------------------------------------------------------

    event DiamondCut(
        IDiamondCut.FacetCut[] _diamondCut,
        address _init,
        bytes _calldata
    );

    function diamondCut(
        IDiamondCut.FacetCut[] memory _cut,
        address _init,
        bytes memory _calldata
    ) internal {
        for (uint256 i; i < _cut.length; i++) {
            IDiamondCut.FacetCutAction action = _cut[i].action;

            if (action == IDiamondCut.FacetCutAction.Add) {
                addFunctions(_cut[i].facetAddress, _cut[i].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Replace) {
                replaceFunctions(_cut[i].facetAddress, _cut[i].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Remove) {
                removeFunctions(_cut[i].facetAddress, _cut[i].functionSelectors);
            } else {
                revert("LibDiamond: Incorrect FacetCutAction");
            }
        }

        emit DiamondCut(_cut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    function addFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(_functionSelectors.length > 0, "LibDiamond: No selectors");
        require(_facetAddress != address(0), "LibDiamond: Zero facet address");

        DiamondStorage storage ds = diamondStorage();

        // Register facet address if new
        if (ds.facetFunctionSelectors[_facetAddress].length == 0) {
            ds.facetAddresses.push(_facetAddress);
        }

        for (uint256 i; i < _functionSelectors.length; i++) {
            bytes4 selector = _functionSelectors[i];
            require(
                ds.selectorToFacetAndPosition[selector].facetAddress == address(0),
                "LibDiamond: Selector already exists"
            );

            ds.selectorToFacetAndPosition[selector] = FacetAddressAndPosition({
                facetAddress: _facetAddress,
                functionSelectorPosition: uint96(
                    ds.facetFunctionSelectors[_facetAddress].length
                )
            });

            ds.facetFunctionSelectors[_facetAddress].push(selector);
        }
    }

    function replaceFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(_functionSelectors.length > 0, "LibDiamond: No selectors");
        require(_facetAddress != address(0), "LibDiamond: Zero facet address");

        DiamondStorage storage ds = diamondStorage();

        if (ds.facetFunctionSelectors[_facetAddress].length == 0) {
            ds.facetAddresses.push(_facetAddress);
        }

        for (uint256 i; i < _functionSelectors.length; i++) {
            bytes4 selector = _functionSelectors[i];
            address oldFacet = ds.selectorToFacetAndPosition[selector].facetAddress;

            require(oldFacet != address(0), "LibDiamond: Selector does not exist");
            require(oldFacet != _facetAddress, "LibDiamond: Same facet");

            // Remove from old facet's selector list
            _removeSelector(ds, oldFacet, selector);

            // Register under new facet
            ds.selectorToFacetAndPosition[selector] = FacetAddressAndPosition({
                facetAddress: _facetAddress,
                functionSelectorPosition: uint96(
                    ds.facetFunctionSelectors[_facetAddress].length
                )
            });

            ds.facetFunctionSelectors[_facetAddress].push(selector);
        }
    }

    function removeFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(_functionSelectors.length > 0, "LibDiamond: No selectors");

        DiamondStorage storage ds = diamondStorage();

        for (uint256 i; i < _functionSelectors.length; i++) {
            bytes4 selector = _functionSelectors[i];
            address existingFacet =
                ds.selectorToFacetAndPosition[selector].facetAddress;

            require(existingFacet != address(0), "LibDiamond: Selector does not exist");
            require(
                existingFacet == _facetAddress,
                "LibDiamond: Wrong facet for selector"
            );

            _removeSelector(ds, _facetAddress, selector);
        }

        // Clean up facet address entry if it has no selectors left
        if (ds.facetFunctionSelectors[_facetAddress].length == 0) {
            _removeFacetAddress(ds, _facetAddress);
        }
    }

    // -------------------------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------------------------

    /// @dev Swap-and-pop a selector out of a facet's selector array
    function _removeSelector(
        DiamondStorage storage ds,
        address _facetAddress,
        bytes4 _selector
    ) private {
        uint96 position =
            ds.selectorToFacetAndPosition[_selector].functionSelectorPosition;
        bytes4[] storage selectors = ds.facetFunctionSelectors[_facetAddress];
        uint256 last = selectors.length - 1;

        if (position != last) {
            bytes4 lastSelector = selectors[last];
            selectors[position] = lastSelector;
            ds.selectorToFacetAndPosition[lastSelector]
                .functionSelectorPosition = position;
        }

        selectors.pop();
        delete ds.selectorToFacetAndPosition[_selector];
    }

    /// @dev Swap-and-pop a facet address out of the facetAddresses array
    function _removeFacetAddress(
        DiamondStorage storage ds,
        address _facetAddress
    ) private {
        uint256 len = ds.facetAddresses.length;
        for (uint256 i; i < len; i++) {
            if (ds.facetAddresses[i] == _facetAddress) {
                ds.facetAddresses[i] = ds.facetAddresses[len - 1];
                ds.facetAddresses.pop();
                break;
            }
        }
    }

    function initializeDiamondCut(
        address _init,
        bytes memory _calldata
    ) internal {
        if (_init == address(0)) return;

        (bool success, bytes memory error) = _init.delegatecall(_calldata);
        if (!success) {
            if (error.length > 0) {
                assembly {
                    revert(add(error, 0x20), mload(error))
                }
            } else {
                revert("LibDiamond: _init reverted");
            }
        }
    }
}
