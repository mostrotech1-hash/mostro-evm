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

    struct VaultAddresses {
        // Hot Vaults — to be populated when Hot/Cold Vault Facets are integrated
        address[] hotVaults;
        // Cold Vaults — to be populated when Hot/Cold Vault Facets are integrated
        address[] coldVaults;
    }

    struct ArtistStorageLayout {
        // artist ID => ArtistRecord
        mapping(uint256 => ArtistRecord) artistsById;
        // token address => artist ID
        mapping(address => uint256) artistIdByToken;
        // artist name hash => artist ID (duplicate name guard)
        mapping(bytes32 => uint256) artistIdByNameHash;
        // total number of artists created — also used as next ID seed
        uint256 artistCount;
    }

    struct ArtistRecord {
        uint256 artistId;
        string  artistName;
        string  tokenName;
        string  tokenSymbol;
        address tokenAddress;
        uint256 totalSupply;
        address beneficiaryWallet;  // optional
        VaultAddresses vaults;
        uint256 createdTimestamp;
        bool    active;
    }
}
