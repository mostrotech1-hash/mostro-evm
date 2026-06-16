// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseColdVault} from "./BaseColdVault.sol";

/**
 * @title PublicPoolVault
 * @notice Cold vault holding 45% of an artist token's supply, designated for public trading.
 * @dev Tokens remain locked until the multisig calls {BaseColdVault-approveDestination}
 *      on the target `UnlockedSaleVault`, then {BaseColdVault-release} to fund it.
 *      The `UnlockedSaleVault` subsequently grants the bonding curve a max approval
 *      to execute buy and sell orders against this allocation.
 */
contract PublicPoolVault is BaseColdVault {
    constructor(address _artistToken, address _releaseController)
        BaseColdVault(_artistToken, _releaseController) {}
}
