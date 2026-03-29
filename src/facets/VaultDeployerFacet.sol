// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {ArtistRevenueVault} from "../../Contracts/mostroVaultContracts/ArtistRevenueVault.sol";
import {ArtistUnvestedVault} from "../../Contracts/mostroVaultContracts/ArtistUnvestedVault.sol";
import {LPVault} from "../../Contracts/mostroVaultContracts/LPVault.sol";
import {MostroGenesisWallet} from "../../Contracts/mostroVaultContracts/MostroGenesisWallet.sol";
import {PlatformUSDCTreasury} from "../../Contracts/mostroVaultContracts/PlatformUSDCTreasury.sol";
import {PublicPoolVault} from "../../Contracts/mostroVaultContracts/PublicPoolVault.sol";
import {StreamFlowEscrowVault} from "../../Contracts/mostroVaultContracts/StreamFlowEscrowVault.sol";
import {UnlockedSaleVault} from "../../Contracts/mostroVaultContracts/UnlockedSaleVault.sol";
import {IMostroStructs} from "../interfaces/IMostroStructs.sol";
import {IVaultDeployerFacet} from "../interfaces/IVaultDeployerFacet.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {VaultDeployerStorage} from "../libraries/StorageLibraries.sol";
import {DiamondReentrancyGuard} from "../libraries/DiamondReentrancyGuard.sol";

/// @title VaultDeployerFacet
/// @notice Mirrors `Contracts/mostroVaultContracts/VaultDeployer.sol` for the Diamond.
///         Uses `address(this)` as vault controller (equivalent to the factory contract there).
contract VaultDeployerFacet is DiamondReentrancyGuard, IMostroStructs, IVaultDeployerFacet {
    using SafeERC20 for IERC20;

    uint256 private constant BPS = 10_000;
    uint256 private constant BPS_PUBLIC_POOL = 4500;
    uint256 private constant BPS_STREAM_FLOW = 4700;
    uint256 private constant BPS_MOSTRO_GENESIS = 300;

    function deployAllVaults(
        address multisig,
        address token,
        address usdc,
        address platformContract,
        address artist,
        address fundingContract,
        uint256 totalTokenAmount
    ) external override nonReentrant returns (DeployedVaults memory vaults) {
        LibDiamond.enforceIsContractOwner();

        if (multisig == address(0)) revert ZeroAddress();
        if (token == address(0)) revert ZeroAddress();
        if (usdc == address(0)) revert ZeroAddress();
        if (platformContract == address(0)) revert ZeroAddress();
        if (artist == address(0)) revert ZeroAddress();
        if (totalTokenAmount > 0 && fundingContract == address(0)) {
            revert ZeroAddress();
        }
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

        if (totalTokenAmount > 0) {
            uint256 allowance = IERC20(token).allowance(
                fundingContract,
                address(this)
            );
            if (allowance < totalTokenAmount) revert InvalidTokenAmount();
        }

        address vaultController = address(this);

        address streamFlowEscrowVault = address(
            new StreamFlowEscrowVault(multisig, token, vaultController)
        );
        address artistUnvestedVault = address(
            new ArtistUnvestedVault(token, artist, streamFlowEscrowVault)
        );
        address artistRevenueVault = address(
            new ArtistRevenueVault(usdc, artist)
        );
        address lpVault = address(new LPVault(multisig, token, vaultController));
        address mostroGenesisWallet = address(
            new MostroGenesisWallet(multisig, token, vaultController)
        );
        address platformUsdcTreasury = address(
            new PlatformUSDCTreasury(multisig, usdc, platformContract)
        );
        address publicPoolVault = address(
            new PublicPoolVault(multisig, token, vaultController)
        );
        address unlockedSaleVault = address(
            new UnlockedSaleVault(multisig, token, vaultController)
        );

        vaults = DeployedVaults({
            artistUnvestedVault: artistUnvestedVault,
            artistRevenueVault: artistRevenueVault,
            lpVault: lpVault,
            mostroGenesisWallet: mostroGenesisWallet,
            platformUsdcTreasury: platformUsdcTreasury,
            publicPoolVault: publicPoolVault,
            streamFlowEscrowVault: streamFlowEscrowVault,
            unlockedSaleVault: unlockedSaleVault
        });

        l.deploymentsByPlatformContract[platformContract] = vaults;

        if (totalTokenAmount > 0) {
            _distributePlatformToken(
                token,
                platformContract,
                totalTokenAmount,
                fundingContract,
                publicPoolVault,
                streamFlowEscrowVault,
                mostroGenesisWallet,
                lpVault
            );
        }

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

    function _allocateAmounts(
        uint256 total
    )
        private
        pure
        returns (
            uint256 publicPool,
            uint256 streamFlow,
            uint256 mostroGenesis,
            uint256 lp
        )
    {
        publicPool = Math.mulDiv(total, BPS_PUBLIC_POOL, BPS);
        streamFlow = Math.mulDiv(total, BPS_STREAM_FLOW, BPS);
        mostroGenesis = Math.mulDiv(total, BPS_MOSTRO_GENESIS, BPS);
        lp = total - publicPool - streamFlow - mostroGenesis;
    }

    function _distributePlatformToken(
        address token,
        address platformContract,
        uint256 totalTokenAmount,
        address fundingContract,
        address publicPoolVault,
        address streamFlowEscrowVault,
        address mostroGenesisWallet,
        address lpVault
    ) private {
        IERC20 t = IERC20(token);
        t.safeTransferFrom(fundingContract, address(this), totalTokenAmount);

        (
            uint256 amountPublic,
            uint256 amountStream,
            uint256 amountGenesis,
            uint256 amountLp
        ) = _allocateAmounts(totalTokenAmount);

        PublicPoolVault(publicPoolVault).depositInPublicVault(
            address(this),
            amountPublic
        );
        StreamFlowEscrowVault(streamFlowEscrowVault).depositInStreamFlowVault(
            address(this),
            amountStream
        );
        MostroGenesisWallet(mostroGenesisWallet).depositInMostroGenesisWallet(
            address(this),
            amountGenesis
        );
        LPVault(lpVault).depositInStreamFlowVault(address(this), amountLp);

        emit TokenAllocationDistributed(
            platformContract,
            token,
            totalTokenAmount,
            amountPublic,
            amountStream,
            amountGenesis,
            amountLp
        );
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
            vaults.artistRevenueVault,
            vaults.lpVault,
            vaults.mostroGenesisWallet,
            vaults.platformUsdcTreasury,
            vaults.publicPoolVault,
            vaults.streamFlowEscrowVault,
            vaults.unlockedSaleVault
        );
    }
}
