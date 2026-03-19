// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ArtistUnvestedVault} from "./ArtistUnvestedVault.sol";
import {LPVault} from "./LPVault.sol";
import {MostroGenesisWallet} from "./MostroGenesisWallet.sol";
import {PlatformUSDCTreasury} from "./PlatformUSDCTreasury.sol";
import {PublicPoolVault} from "./PublicPoolVault.sol";
import {StreamFlowEscrowVault} from "./StreamFlowEscrowVault.sol";
import {UnlockedSaleVault} from "./UnlockedSaleVault.sol";

/// @title VaultDeployer
/// @notice Deploys all vault contracts used by the protocol.
contract VaultDeployer {
    struct DeployedVaults {
        address artistUnvestedVault;
        address lpVault;
        address mostroGenesisWallet;
        address platformUsdcTreasury;
        address publicPoolVault;
        address streamFlowEscrowVault;
        address unlockedSaleVault;
    }

    mapping(address => DeployedVaults) private deploymentsByPlatformContract;
    address public immutable CONTRACT;

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
    error NotContract();
    error InvalidContractAddress(address addr);
    error DeploymentAlreadyExists(address platformContract);

    constructor(address _contract) {
        if (_contract == address(0)) revert ZeroAddress();
        CONTRACT = _contract;
    }

    /// @notice Deploy all concrete contracts in `src/`.
    /// @param multisig The global multisig contract (e.g. Safe).
    /// @param token The platform token address used by token vaults.
    /// @param usdc The USDC token address used by PlatformUSDCTreasury.
    /// @param platformContract Platform instance key for this deployment record.
    ///        `CONTRACT` is the only caller allowed to execute this function,
    ///        but it may register deployments for different platform contracts.
    /// @param artist The artist wallet for ArtistUnvestedVault.
    function deployAllVaults(
        address multisig,
        address token,
        address usdc,
        address platformContract,
        address artist
    ) external onlyContract returns (DeployedVaults memory vaults) {
        
        if (multisig == address(0)) revert ZeroAddress();
        if (token == address(0)) revert ZeroAddress();
        if (usdc == address(0)) revert ZeroAddress();
        if (platformContract == address(0)) revert ZeroAddress();
        if (artist == address(0)) revert ZeroAddress();
        if (multisig.code.length == 0) revert InvalidContractAddress(multisig);
        if (token.code.length == 0) revert InvalidContractAddress(token);
        if (usdc.code.length == 0) revert InvalidContractAddress(usdc);
        if (platformContract.code.length == 0)
            revert InvalidContractAddress(platformContract);
        if (
            deploymentsByPlatformContract[platformContract].lpVault !=
            address(0)
        ) {
            revert DeploymentAlreadyExists(platformContract);
        }

        StreamFlowEscrowVault streamFlowEscrowVault = new StreamFlowEscrowVault(
            multisig,
            token,
            platformContract
        );

        ArtistUnvestedVault artistUnvestedVault = new ArtistUnvestedVault(
            token,
            artist,
            address(streamFlowEscrowVault)
        );

        LPVault lpVault = new LPVault(multisig, token, platformContract);
        MostroGenesisWallet mostroGenesisWallet = new MostroGenesisWallet(
            multisig,
            token,
            platformContract
        );
        PlatformUSDCTreasury platformUsdcTreasury = new PlatformUSDCTreasury(
            multisig,
            usdc,
            platformContract
        );
        PublicPoolVault publicPoolVault = new PublicPoolVault(
            multisig,
            token,
            platformContract
        );
        UnlockedSaleVault unlockedSaleVault = new UnlockedSaleVault(
            multisig,
            token,
            platformContract
        );

        vaults = DeployedVaults({
            artistUnvestedVault: address(artistUnvestedVault),
            lpVault: address(lpVault),
            mostroGenesisWallet: address(mostroGenesisWallet),
            platformUsdcTreasury: address(platformUsdcTreasury),
            publicPoolVault: address(publicPoolVault),
            streamFlowEscrowVault: address(streamFlowEscrowVault),
            unlockedSaleVault: address(unlockedSaleVault)
        });

        deploymentsByPlatformContract[platformContract] = vaults;

        _emitVaultsDeployed(multisig, platformContract, vaults);
    }

    function getDeploymentByPlatformContract(
        address platformContract
    ) external view returns (DeployedVaults memory vaults) {
        return deploymentsByPlatformContract[platformContract];
    }

    modifier onlyContract() {
        _onlyContract();
        _;
    }

    function _onlyContract() internal view {
        if (msg.sender != CONTRACT) revert NotContract();
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
