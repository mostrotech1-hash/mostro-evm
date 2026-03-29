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

    // Storage struct for vault deployment records
    struct DeployedVaults {
        address artistUnvestedVault;
        address artistRevenueVault;
        address lpVault;
        address mostroGenesisWallet;
        address platformUsdcTreasury;
        address publicPoolVault;
        address streamFlowEscrowVault;
        address unlockedSaleVault;
    }

    // Storage struct for vault deployer domain
    struct VaultDeployerLayout {
        mapping(address platformContract => DeployedVaults deployedVaults)
            deploymentsByPlatformContract;
    }

}
