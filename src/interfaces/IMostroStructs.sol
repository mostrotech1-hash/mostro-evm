// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMostroStructs {

    // Storage struct for TestFacet domain
    struct TestData {
        uint256 value;
    }

    // Storage struct for Diamond init tracking
    struct DiamondLayout {
        bool isInit;
    }

    // Storage struct for Config domain

    struct ConfigLayout {
        address multisigContract;
    }

    // Storage struct for Mostro Role Manager
    struct MostroRoleManagerLayout {
        mapping(address => bool) admins;
        mapping(address => bool) superAdmins;
        uint256 adminCount;
        uint256 superAdminCount;
    }

    // Storage struct for reentrancy guard
    struct ReentrancyLayout {
        uint256 status;
    }

    // Storage struct for Mostro Factory
    struct MostroFactoryLayout {
        uint256 artistCount;
        mapping(bytes32 => address) artistTokens;            // keccak256(artistId) => token address
        mapping(address => address) publicPoolVaults;        // artist token => publicPoolVault address
        mapping(address => address) streamflowEscrowVaults;  // artist token => streamflowEscrowVault address
        mapping(address => address) lpVaults;                // artist token => LPVault address
        mapping(address => address) genesisVaults;           // artist token => GenesisVault address
        mapping(address => uint256) publicPoolAllocations;   // artist token => allocated amount
        mapping(address => uint256) streamflowEscrowAllocations;
        mapping(address => uint256) lpAllocations;
        mapping(address => uint256) genesisAllocations;
        mapping(address => address) publicPoolHotVaults;     // artist token => approved hot vault
        mapping(address => address) streamflowHotVaults;
        mapping(address => address) lpHotVaults;
        mapping(address => address) genesisHotVaults;
    }
}
