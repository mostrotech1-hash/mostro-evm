// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ArtistUnvestedVault} from "../../Contracts/monstroVaultContracts/ArtistUnvestedVault.sol";
import {LPVault} from "../../Contracts/monstroVaultContracts/LPVault.sol";
import {MostroGenesisWallet} from "../../Contracts/monstroVaultContracts/MostroGenesisWallet.sol";
import {PlatformUSDCTreasury} from "../../Contracts/monstroVaultContracts/PlatformUSDCTreasury.sol";
import {PublicPoolVault} from "../../Contracts/monstroVaultContracts/PublicPoolVault.sol";
import {StreamFlowEscrowVault} from "../../Contracts/monstroVaultContracts/StreamFlowEscrowVault.sol";
import {UnlockedSaleVault} from "../../Contracts/monstroVaultContracts/UnlockedSaleVault.sol";
import {IMostroStructs} from "../interfaces/IMostroStructs.sol";
import {IVaultDeployerFacet} from "../interfaces/IVaultDeployerFacet.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {VaultDeployerStorage} from "../libraries/StorageLibraries.sol";

/// @title VaultDeployerFacet
/// @notice Facet that deploys all monstro vault contracts and stores deployment records.
contract VaultDeployerFacet is IMostroStructs, IVaultDeployerFacet {
    function deployAllVaults(
        address multisig,
        address token,
        address usdc,
        address platformContract,
        address artist
    ) external override returns (DeployedVaults memory vaults) {
        LibDiamond.enforceIsContractOwner();

        if (multisig == address(0)) revert ZeroAddress();
        if (token == address(0)) revert ZeroAddress();
        if (usdc == address(0)) revert ZeroAddress();
        if (platformContract == address(0)) revert ZeroAddress();
        if (artist == address(0)) revert ZeroAddress();
        if (multisig.code.length == 0) revert InvalidContractAddress(multisig);
        if (token.code.length == 0) revert InvalidContractAddress(token);
        if (usdc.code.length == 0) revert InvalidContractAddress(usdc);
        if (platformContract.code.length == 0) {
            revert InvalidContractAddress(platformContract);
        }

        IMostroStructs.VaultDeployerLayout storage l = VaultDeployerStorage
            .layout();
        if (
            l.deploymentsByPlatformContract[platformContract].lpVault !=
            address(0)
        ) {
            revert DeploymentAlreadyExists(platformContract);
        }

        address streamFlowEscrowVault = address(
            new StreamFlowEscrowVault(multisig, token, platformContract)
        );
        address artistUnvestedVault = address(
            new ArtistUnvestedVault(token, artist, streamFlowEscrowVault)
        );
        address lpVault = address(new LPVault(multisig, token, platformContract));
        address mostroGenesisWallet = address(
            new MostroGenesisWallet(multisig, token, platformContract)
        );
        address platformUsdcTreasury = address(
            new PlatformUSDCTreasury(multisig, usdc, platformContract)
        );
        address publicPoolVault = address(
            new PublicPoolVault(multisig, token, platformContract)
        );
        address unlockedSaleVault = address(
            new UnlockedSaleVault(multisig, token, platformContract)
        );

        vaults = DeployedVaults({
            artistUnvestedVault: artistUnvestedVault,
            lpVault: lpVault,
            mostroGenesisWallet: mostroGenesisWallet,
            platformUsdcTreasury: platformUsdcTreasury,
            publicPoolVault: publicPoolVault,
            streamFlowEscrowVault: streamFlowEscrowVault,
            unlockedSaleVault: unlockedSaleVault
        });

        l.deploymentsByPlatformContract[platformContract] = vaults;

        _emitVaultsDeployed(multisig, platformContract, vaults);
    }

    function getDeploymentByPlatformContract(
        address platformContract
    ) external view override returns (DeployedVaults memory vaults) {
        return
            VaultDeployerStorage.layout().deploymentsByPlatformContract[
                platformContract
            ];
    }

    function _emitVaultsDeployed(
        address multisig,
        address platformContract,
        DeployedVaults memory vaults
    ) internal {
        emit VaultsDeployed(
            msg.sender,
            multisig,
            platformContract,
            vaults.artistUnvestedVault,
            vaults.lpVault,
            vaults.mostroGenesisWallet,
            vaults.platformUsdcTreasury,
            vaults.publicPoolVault,
            vaults.streamFlowEscrowVault,
            vaults.unlockedSaleVault
        );
    }
}
