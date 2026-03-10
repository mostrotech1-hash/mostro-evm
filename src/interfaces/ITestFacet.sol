// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITestFacet {
    function setValue(uint256 value) external;
    function getValue() external view returns (uint256);
}