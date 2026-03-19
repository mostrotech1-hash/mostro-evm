// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IMostroStructs} from "./IMostroStructs.sol";

interface IVaultDeployerFacet is IMostroStructs {
    event VaultsDeployed(
        address indexed deployer,
        address indexed multisig,
        address indexed platformContract,
        address artistUnvestedVault,
        address lpVault,
        address mostroGenesisWallet,
        address platformUsdcTreasury,
        address publicPoolVault,
        address streamFlowEscrowVault,
        address unlockedSaleVault
    );

    error ZeroAddress();
    error InvalidContractAddress(address addr);
    error DeploymentAlreadyExists(address platformContract);

    function deployAllVaults(
        address multisig,
        address token,
        address usdc,
        address platformContract,
        address artist
    ) external returns (DeployedVaults memory vaults);

    function getDeploymentByPlatformContract(
        address platformContract
    ) external view returns (DeployedVaults memory vaults);
}
