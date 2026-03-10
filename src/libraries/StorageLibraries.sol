// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IMostroStructs} from "../interfaces/IMostroStructs.sol";

/**
 * @notice One storage library per feature domain.
 *         Replaces the inline `library LibTest` from the zip template.
 *         Each library owns one unique keccak256 slot.
 *
 * WHY internal view NOT internal pure:
 *   Returning a storage pointer is a state-read — pure is semantically wrong.
 */

library TestStorage {
    bytes32 internal constant STORAGE_SLOT =
    keccak256("mostro.storage.test");

    function layout()
    internal
    view
    returns (IMostroStructs.TestData storage l)
    {
        bytes32 slot = STORAGE_SLOT;
        assembly { l.slot := slot }
    }
}

library DiamondLayoutStorage {
    bytes32 internal constant STORAGE_SLOT =
    keccak256("mostro.storage.diamond.layout");

    function layout()
    internal
    view
    returns (IMostroStructs.DiamondLayout storage l)
    {
        bytes32 slot = STORAGE_SLOT;
        assembly { l.slot := slot }
    }
}

library ConfigStorage {
    bytes32 internal constant STORAGE_SLOT =
    keccak256("mostro.storage.config");

    function layout()
    internal
    view
    returns (IMostroStructs.ConfigLayout storage l)
    {
        bytes32 slot = STORAGE_SLOT;
        assembly { l.slot := slot }
    }
}