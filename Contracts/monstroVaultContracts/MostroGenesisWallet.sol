// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseVault} from "./BaseVault.sol";

/// @title  MostroGenesisWallet
/// @notice Core platform wallet — 3% of supply.
///         Used for governance, early operations, and strategic disbursements.
///         All movements require multisig approval.
contract MostroGenesisWallet is BaseVault {
    string public constant VAULT_NAME = "MostroGenesisWallet";

    constructor(
        address _multisig,
        address _token,
        address _contract
    ) BaseVault(_multisig, _token, _contract) {}

    /// @notice Disburse tokens with a tagged purpose for on-chain auditability.
    function withdraw(address recipient, uint256 amount) external onlyMultisig {
        _release(recipient, amount);
    }

    function depositInMostroGenesisWallet(
        address from,
        uint256 amount
    ) external onlyContract {
        _deposit(from, amount);
    }
}
