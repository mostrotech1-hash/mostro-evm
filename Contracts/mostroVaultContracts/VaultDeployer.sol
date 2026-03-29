// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ArtistUnvestedVault} from "./ArtistUnvestedVault.sol";
import {ArtistRevenueVault} from "./ArtistRevenueVault.sol";
import {LPVault} from "./LPVault.sol";
import {MostroGenesisWallet} from "./MostroGenesisWallet.sol";
import {PlatformUSDCTreasury} from "./PlatformUSDCTreasury.sol";
import {PublicPoolVault} from "./PublicPoolVault.sol";
import {StreamFlowEscrowVault} from "./StreamFlowEscrowVault.sol";
import {UnlockedSaleVault} from "./UnlockedSaleVault.sol";

/// @title VaultDeployer
/// @notice Factory: deploys all vault contracts and optionally allocates the platform token
///         per supply schedule (Public Pool 45%, StreamFlow 47%, Mostro Genesis 3%, LP 5%).
contract VaultDeployer is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @dev Basis points denominator (100%).
    uint256 private constant BPS = 10_000;
    /// @dev Public Pool Vault — 45%.
    uint256 private constant BPS_PUBLIC_POOL = 4500;
    /// @dev StreamFlow Escrow Vault — 47%.
    uint256 private constant BPS_STREAM_FLOW = 4700;
    /// @dev Mostro Genesis Wallet — 3%.
    uint256 private constant BPS_MOSTRO_GENESIS = 300;
    /// @dev LP Vault — 5%.
    uint256 private constant BPS_LP = 500;

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

    mapping(address => DeployedVaults) private deploymentsByPlatformContract;
    address public immutable CONTRACT;

    event VaultsDeployed(
        address indexed deployer,
        address indexed multisig,
        address indexed platformContract,
        address artistUnvestedVault,
        address artistRevenueVault,
        address lpVault,
        address mostroGenesisWallet,
        address platformUsdcTreasury,
        address publicPoolVault,
        address streamFlowEscrowVault,
        address unlockedSaleVault
    );

    event TokenAllocationDistributed(
        address indexed platformContract,
        address indexed token,
        uint256 totalAmount,
        uint256 publicPoolAmount,
        uint256 streamFlowAmount,
        uint256 mostroGenesisAmount,
        uint256 lpVaultAmount
    );

    error ZeroAddress();
    error NotContract();
    error InvalidContractAddress(address addr);
    error DeploymentAlreadyExists(address platformContract);
    error InvalidTokenAmount();

    /*
     * Sets immutable controller contract that is allowed to trigger deployments.
     */
    constructor(address _contract) {
        if (_contract == address(0)) revert ZeroAddress();
        CONTRACT = _contract;
    }

    /*
     * Deploys all vault contracts and stores deployed addresses by platformContract key.
     * If `totalTokenAmount > 0`, this contract pulls `token` from `CONTRACT` and distributes
     * it to PublicPool, StreamFlow, MostroGenesis, and LP vaults by BPS schedule.
     * Token flow (optional funding step):
     * `CONTRACT` -> `address(this)` -> allocation vault contracts.
     */
    function deployAllVaults(
        address multisig,
        address token,
        address usdc,
        address platformContract,
        address artist,
        uint256 totalTokenAmount
    ) external onlyContract nonReentrant returns (DeployedVaults memory vaults) {
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

        if (totalTokenAmount > 0) {
            uint256 allowance = IERC20(token).allowance(CONTRACT, address(this));
            if (allowance < totalTokenAmount) revert InvalidTokenAmount();
        }

        address vaultController = address(this);

        StreamFlowEscrowVault streamFlowEscrowVault = new StreamFlowEscrowVault(
            multisig,
            token,
            vaultController
        );

        ArtistUnvestedVault artistUnvestedVault = new ArtistUnvestedVault(
            token,
            artist,
            address(streamFlowEscrowVault)
        );
        ArtistRevenueVault artistRevenueVault = new ArtistRevenueVault(
            usdc,
            artist
        );

        LPVault lpVault = new LPVault(multisig, token, vaultController);
        MostroGenesisWallet mostroGenesisWallet = new MostroGenesisWallet(
            multisig,
            token,
            vaultController
        );
        PlatformUSDCTreasury platformUsdcTreasury = new PlatformUSDCTreasury(
            multisig,
            usdc,
            platformContract
        );
        PublicPoolVault publicPoolVault = new PublicPoolVault(
            multisig,
            token,
            vaultController
        );
        UnlockedSaleVault unlockedSaleVault = new UnlockedSaleVault(
            multisig,
            token,
            vaultController
        );

        vaults = DeployedVaults({
            artistUnvestedVault: address(artistUnvestedVault),
            artistRevenueVault: address(artistRevenueVault),
            lpVault: address(lpVault),
            mostroGenesisWallet: address(mostroGenesisWallet),
            platformUsdcTreasury: address(platformUsdcTreasury),
            publicPoolVault: address(publicPoolVault),
            streamFlowEscrowVault: address(streamFlowEscrowVault),
            unlockedSaleVault: address(unlockedSaleVault)
        });

        deploymentsByPlatformContract[platformContract] = vaults;

        if (totalTokenAmount > 0) {
            _distributePlatformToken(
                token,
                platformContract,
                totalTokenAmount,
                publicPoolVault,
                streamFlowEscrowVault,
                mostroGenesisWallet,
                lpVault
            );
        }

        _emitVaultsDeployed(multisig, platformContract, vaults);
    }

    /*
     * Returns stored deployment addresses for a specific platformContract key.
     */
    function getDeploymentByPlatformContract(
        address platformContract
    ) external view returns (DeployedVaults memory vaults) {
        return deploymentsByPlatformContract[platformContract];
    }

    /*
     * Restricts function execution to immutable `CONTRACT`.
     */
    modifier onlyContract() {
        _onlyContract();
        _;
    }

    /*
     * Reverts unless caller is immutable `CONTRACT`.
     */
    function _onlyContract() internal view {
        if (msg.sender != CONTRACT) revert NotContract();
    }

    /*
     * Splits total token amount into BPS-based allocation amounts.
     * No token transfer happens here; this is pure math.
     */
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

    /*
     * Pulls platform token from `CONTRACT`, then funds allocation vaults once each.
     * Token flow:
     * 1) `CONTRACT` -> `address(this)` via safeTransferFrom
     * 2) `address(this)` -> each vault via vault-specific deposit functions
     */
    function _distributePlatformToken(
        address token,
        address platformContract,
        uint256 totalTokenAmount,
        PublicPoolVault publicPoolVault,
        StreamFlowEscrowVault streamFlowEscrowVault,
        MostroGenesisWallet mostroGenesisWallet,
        LPVault lpVault
    ) private {
        IERC20 t = IERC20(token);
        t.safeTransferFrom(CONTRACT, address(this), totalTokenAmount);

        (
            uint256 amountPublic,
            uint256 amountStream,
            uint256 amountGenesis,
            uint256 amountLp
        ) = _allocateAmounts(totalTokenAmount);

        publicPoolVault.depositInPublicVault(address(this), amountPublic);
        streamFlowEscrowVault.depositInStreamFlowVault(
            address(this),
            amountStream
        );
        mostroGenesisWallet.depositInMostroGenesisWallet(
            address(this),
            amountGenesis
        );
        lpVault.depositInStreamFlowVault(address(this), amountLp);

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

    /*
     * Emits full deployment result for indexing and integrations.
     */
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
