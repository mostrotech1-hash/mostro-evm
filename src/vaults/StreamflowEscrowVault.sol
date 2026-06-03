// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseColdVault} from "./BaseColdVault.sol";

contract StreamflowEscrowVault is BaseColdVault {
    constructor(address _artistToken, address _releaseController)
        BaseColdVault(_artistToken, _releaseController) {}
}
