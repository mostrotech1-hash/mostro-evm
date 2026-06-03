// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseColdVault} from "./BaseColdVault.sol";

/**
 * @title LPVault
 * @notice Cold vault holding 5% of an artist token's supply, designated for liquidity provision.
 * @dev Tokens remain locked until the multisig releases them to the `LPOperationalDestination`
 *      (hot vault), which grants a DEX liquidity router a max approval to deploy them
 *      into a trading pool. The liquidity router address is set on the hot vault
 *      separately by the Diamond.
 */
contract LPVault is BaseColdVault {
    constructor(address _artistToken, address _releaseController)
        BaseColdVault(_artistToken, _releaseController) {}
}
