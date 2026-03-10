// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IMostroStructs} from "../interfaces/IMostroStructs.sol";
import {ITestFacet} from "../interfaces/ITestFacet.sol";
import {TestStorage} from "../libraries/StorageLibraries.sol";

/**
 * @title TestFacet
 * @notice Restructured from the zip template to follow the CDK project pattern:
 *
 *   BEFORE (zip):
 *     library LibTest { struct TestStorage { uint256 value; } ... }
 *     contract TestFacet { setValue / getValue }
 *
 *   AFTER (CDK pattern):
 *     IMostroStructs  — shared struct definition (TestData)
 *     StorageLibraries — namespaced slot via TestStorage library
 *     ITestFacet       — public ABI interface
 *     TestFacet        — business logic only
 */
contract TestFacet is IMostroStructs, ITestFacet {

    event ValueSet(uint256 newValue);

    function setValue(uint256 _value) external override {
        TestStorage.layout().value = _value;
        emit ValueSet(_value);
    }

    function getValue() external view override returns (uint256) {
        return TestStorage.layout().value;
    }
}