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

    // Storage struct for Mostro Factory
    struct MostroFactoryLayout {
        uint256 artistCount;
        mapping(string => address) artistTokens;             // artist name => token address
        mapping(address => address) publicPoolVaults;        // artist token => publicPoolVault address
        mapping(address => address) streamflowEscrowVaults;  // artist token => streamflowEscrowVault address
        mapping(address => address) lpVaults;                // artist token => LPVault address
    }
}
