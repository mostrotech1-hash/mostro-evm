// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IConfigFacet} from "../interfaces/IConfigFacet.sol";
import {IMostroStructs} from "../interfaces/IMostroStructs.sol";
import {ConfigStorage} from "../libraries/StorageLibraries.sol";

/// @title ConfigFacet
/// @notice Manages administrative and operational configuration of the Diamond.
contract ConfigFacet is IMostroStructs, IConfigFacet {

    /* -----------------  Events  ----------------- */

    event Config_MultisigContractUpdated(address multisigContract);

    /* -----------------  Modifiers  ----------------- */

    // TODO: wire up your AccessControlFacet here once implemented
    // modifier callerMustBeSuperAdminOrAdmin(address _caller) { ... }

    /* -----------------  Functions  ----------------- */

    /// @notice Returns the address of the multisig contract.
    function getMultisigContract() external view override returns (address) {
        return ConfigStorage.layout().multisigContract;
    }

    /// @notice Sets the address of the multisig contract.
    /// @param _multisigContract The new multisig address.
    function setMultisigContract(address _multisigContract) external override {
        require(
            _multisigContract != address(0),
            "ConfigFacet: multisig is zero address"
        );
        require(
            _multisigContract != ConfigStorage.layout().multisigContract,
            "ConfigFacet: same multisig address"
        );
        ConfigStorage.layout().multisigContract = _multisigContract;
        emit Config_MultisigContractUpdated(_multisigContract);
    }
}