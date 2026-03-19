// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseVault} from "./BaseVault.sol";

/// @title  UnlockedSaleVault
/// @notice Hot operational vault that receives token tranches from PublicPoolVault
///         and dispenses them through the bonding curve sale mechanism.
///         The bonding curve contract itself must be set by the multisig —
///         it is the only non-multisig address permitted to pull tokens.
contract UnlockedSaleVault is BaseVault {
    string public constant VAULT_NAME = "UnlockedSaleVault";

    event SaleTransfer(address indexed buyer, uint256 amount);

    constructor(
        address _multisig,
        address _token,
        address _contract
    ) BaseVault(_multisig, _token, _contract) {}

    function receiveFromPublicVault(
        address from,
        uint256 amount
    ) external onlyContract {
        _deposit(from, amount);
    }
}
