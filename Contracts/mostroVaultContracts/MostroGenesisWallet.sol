// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseVault} from "./BaseVault.sol";

/// @title  MostroGenesisWallet
/// @notice Core platform wallet — 3% of supply.
///         Used for governance, early operations, and strategic disbursements.
///         All movements require multisig approval.
contract MostroGenesisWallet is BaseVault {
    string public constant VAULT_NAME = "MostroGenesisWallet";

    /*
     * Initializes BaseVault with multisig, TOKEN, and controller contract.
     */
    constructor(
        address _multisig,
        address _token,
        address _contract
    ) BaseVault(_multisig, _token, _contract) {}

    /*
     * Multisig-controlled token withdrawal.
     * Token flow: `address(this)` -> `recipient`.
     */
    function withdraw(address recipient, uint256 amount) external onlyMultisig {
        _release(recipient, amount);
    }

    /*
     * One-time controller deposit into genesis wallet.
     * Token flow: `from` -> `address(this)`.
     */
    function depositInMostroGenesisWallet(
        address from,
        uint256 amount
    ) external onlyContract {
        _deposit(from, amount);
    }
}
