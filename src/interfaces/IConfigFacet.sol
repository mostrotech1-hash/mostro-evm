// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IConfigFacet
/// @notice Public ABI for ConfigFacet.
interface IConfigFacet {
    function getMultisigContract() external view returns (address);
    function setMultisigContract(address multisigContract) external;
}