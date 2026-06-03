// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseColdVault} from "./BaseColdVault.sol";

/**
 * @title GenesisVault
 * @notice Cold vault holding the remainder of an artist token's supply (~3%), designated for genesis sales.
 * @dev Receives the arithmetic remainder after the three other vaults are allocated, guaranteeing
 *      that 100% of the supply is distributed with zero dust loss.
 *      Tokens remain locked until the multisig releases them to the `PlatformTreasury` (hot vault),
 *      from which the Diamond can withdraw to any address.
 */
contract GenesisVault is BaseColdVault {
    constructor(address _artistToken, address _releaseController)
        BaseColdVault(_artistToken, _releaseController) {}
}
