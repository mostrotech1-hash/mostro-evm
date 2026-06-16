// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseColdVault} from "./BaseColdVault.sol";

/**
 * @title StreamflowEscrowVault
 * @notice Cold vault holding 47% of an artist token's supply, designated for artist vesting.
 * @dev Tokens remain locked until the multisig releases them to the `ArtistUnvestedVault`
 *      (hot vault), which holds them pending integration with Streamflow for on-chain
 *      vesting streams. The artist address is registered on the hot vault separately
 *      by the Diamond.
 */
contract StreamflowEscrowVault is BaseColdVault {
    constructor(address _artistToken, address _releaseController)
        BaseColdVault(_artistToken, _releaseController) {}
}
