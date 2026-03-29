// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseVault} from "./BaseVault.sol";

/// @title  LPVault
/// @notice Holds 5% of platform token supply locked until
///         the multisig initiates genesis LP creation on Raydium.
contract LPVault is BaseVault {
    string public constant VAULT_NAME = "LPVault";

    /*
     * Initializes BaseVault with multisig, TOKEN, and controller contract.
     */
    constructor(address _multisig,address _token, address _contract) BaseVault(_multisig, _token, _contract) {}

    /*
     * Releases TOKEN to LP destination.
     * Token flow: `address(this)` -> `recipient`.
     * Callable only by MULTISIG.
     */
    function release(address recipient, uint256 amount) external onlyMultisig {
        _release(recipient, amount);
    }

    /*
     * One-time controller deposit into LP vault using BaseVault._deposit.
     * Token flow: `from` -> `address(this)`.
     */
    function depositInStreamFlowVault(address from, uint256 amount) external onlyContract {
        _deposit(from,amount);
    }
}
