// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseVault} from "./BaseVault.sol";

/// @title  PublicPoolVault
/// @notice Holds 40% of platform token supply.
///         Releases tokens to the UnlockedSaleVault in tranches
///         controlled entirely by the global multisig.
contract PublicPoolVault is BaseVault {
    string public constant VAULT_NAME = "PublicPoolVault";

    constructor(
        address _multisig,
        address _token,
        address _contract
    ) BaseVault(_multisig, _token, _contract) {}

    /// @notice Release a tranche to the unlocked sale vault (or any recipient).
    function releaseTranche(
        address destination,
        uint256 amount
    ) external onlyMultisig {
        _release(destination, amount);
    }

    function depositInPublicVault(
        address from,
        uint256 amount
    ) external onlyContract {
        _deposit(from, amount);
    }
}
