// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IMostroStructs} from "../interfaces/IMostroStructs.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {DiamondLayoutStorage} from "../libraries/StorageLibraries.sol";

/**
 * @title DiamondInit
 * @notice Called ONCE via delegatecall during the initial diamondCut.
 *         Restructured from the zip stub to seed storage via storage libs,
 *         following the CDK project pattern.
 *
 * @dev Never deployed standalone — always used as _init target in diamondCut.
 *
 * WHY NO OwnershipFacet:
 *   Access control is managed via role-based storage (ADMIN/SUPER_ADMIN).
 *   LibDiamond.contractOwner guards diamondCut() only and is never exposed
 *   as a public facet function.
 */
contract DiamondInit is IMostroStructs {

    struct InitParams {
        bool isInit; // extend with your domain params as you add facets
    }

    function init(InitParams calldata p) external {

        // 1. Confirm upgrade-owner was set in Diamond constructor
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(ds.contractOwner != address(0), "DiamondInit: no owner set");

        // 2. Seed DiamondLayoutStorage
        DiamondLayoutStorage.layout().isInit = p.isInit;
    }
}