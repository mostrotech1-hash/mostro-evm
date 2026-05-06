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

    // Storage struct for Token Factory
    struct VaultAddresses {
        address publicPoolVault;
        address streamFlowEscrowVault;
        address mostroGenesisWallet;
        address lpVault;
        address platformUsdcTreasury;
        address unlockedSaleVault;
        address artistUnvestedVault;
    }

    struct TokenRecord {
        address tokenAddress;
        string  tokenName;
        string  tokenSymbol;
        address artistWallet;
        uint256 totalSupply;
        uint256 launchTimestamp;
        VaultAddresses vaults;
    }

    struct TokenFactoryLayout {
        // token address => TokenRecord
        mapping(address => TokenRecord) tokenRecords;
        // artist wallet => token addresses
        mapping(address => address[]) tokensByArtist;
        // token address => artist wallet
        mapping(address => address) artistByToken;
        // all launched token addresses
        address[] allLaunchedTokens;
    }


}
