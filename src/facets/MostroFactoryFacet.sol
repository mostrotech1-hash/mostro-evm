// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IMostroFactory} from '../interfaces/IMostroFactory.sol';
import {IMostroStructs} from '../interfaces/IMostroStructs.sol';
import {MostroFactoryStorage, MostroRoleManagerStorage, ConfigStorage} from '../libraries/StorageLibraries.sol';
import {PublicPoolVault} from '../vaults/PublicPoolVault.sol';
import {StreamflowEscrowVault} from '../vaults/StreamflowEscrowVault.sol';
import {LPVault} from '../vaults/LPVault.sol';
import {GenesisVault} from '../vaults/GenesisVault.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/**
 * @title MostroFactoryFacet
 * @notice Initializes the cold vault infrastructure for a single artist token, distributing
 *         100% of the token supply atomically across four purpose-specific cold vaults.
 * @dev Diamond facet (EIP-2535). All state is written to Diamond storage via {MostroFactoryStorage},
 *      {MostroRoleManagerStorage}, and {ConfigStorage} to prevent slot collisions across facets.
 *
 *      Prerequisites before calling {initializeColdVaults}:
 *        - Artist token must be minted externally and the full supply held by the Diamond.
 *        - Multisig address must be registered in {ConfigStorage}.
 *        - Four hot vault contracts must be deployed and their addresses known.
 *
 *      Post-conditions after a successful call:
 *        - Diamond holds zero tokens of `tokenAddress`.
 *        - Four cold vaults hold exactly `totalSupply` tokens in aggregate.
 *        - Each vault's `releaseController` is set to the multisig.
 *        - Intended hot vault destinations are registered in Diamond storage for multisig reference.
 */
contract MostroFactoryFacet is IMostroStructs, IMostroFactory {

    // ─── Constants ────────────────────────────────────────

    /// @notice Public pool vault allocation in basis points. Represents 45.00% of total supply.
    uint256 public constant PUBLIC_POOL_BPS       = 4500;

    /// @notice Streamflow escrow vault allocation in basis points. Represents 47.00% of total supply.
    uint256 public constant STREAMFLOW_ESCROW_BPS = 4700;

    /// @notice LP vault allocation in basis points. Represents 5.00% of total supply.
    uint256 public constant LP_BPS                = 500;

    /// @notice Genesis vault allocation in basis points. Derived at compile time as the remainder
    ///         of 10000 minus the three explicit allocations. Absorbs integer division dust,
    ///         guaranteeing exactly 100% supply distribution. Underflows at compile time if
    ///         the other constants exceed 10000, acting as a built-in invariant check.
    uint256 public constant GENESIS_BPS           = 10000 - PUBLIC_POOL_BPS - STREAMFLOW_ESCROW_BPS - LP_BPS;

    // ─── Modifiers ────────────────────────────────────────

    /**
     * @dev Reads role state from {MostroRoleManagerStorage}. Permits both `admins` and
     *      `superAdmins`. Reverts with {Unauthorized} if `msg.sender` matches neither mapping.
     */
    modifier onlyAdminOrSuperAdmin() {
        MostroRoleManagerLayout storage roles = MostroRoleManagerStorage.layout();
        if (!roles.admins[msg.sender] && !roles.superAdmins[msg.sender]) revert Unauthorized();
        _;
    }

    // ─── Factory Functions ─────────────────────────────────

    /**
     * @notice Deploys and funds the four cold vaults for a previously minted artist token.
     * @dev Callable once per `artistId`. Allocation order is fixed: public pool → streamflow
     *      → LP → genesis. The genesis vault always receives the exact arithmetic remainder,
     *      capturing any integer division dust to guarantee `sum(allocations) == totalSupply`.
     *
     *      Emits {PublicPoolVaultCreated}, {StreamflowEscrowVaultCreated}, {LPVaultCreated},
     *      and {GenesisVaultCreated}.
     *
     * @param artistId           Unique string identifier for the artist. Immutable once registered.
     * @param tokenAddress       Address of the ERC20 artist token. The Diamond must hold at least
     *                           `totalSupply` of this token before the call.
     * @param totalSupply        Expected total token supply in base units. Used for allocation
     *                           math and pre-call balance verification.
     * @param publicPoolHotVault Intended downstream hot vault for the public pool cold vault.
     *                           Stored in Diamond storage; multisig must call
     *                           {BaseColdVault-approveDestination} on the cold vault separately.
     * @param streamflowHotVault Intended downstream hot vault for the Streamflow escrow cold vault.
     * @param lpHotVault         Intended downstream hot vault for the LP cold vault.
     * @param genesisHotVault    Intended downstream hot vault for the genesis cold vault.
     */
    function initializeColdVaults(
        string calldata artistId,
        address tokenAddress,
        uint256 totalSupply,
        address publicPoolHotVault,
        address streamflowHotVault,
        address lpHotVault,
        address genesisHotVault
    ) external onlyAdminOrSuperAdmin {
        if (bytes(artistId).length == 0) revert InvalidArtistId();
        if (
            tokenAddress == address(0) ||
            publicPoolHotVault == address(0) ||
            streamflowHotVault == address(0) ||
            lpHotVault == address(0) ||
            genesisHotVault == address(0)
        ) revert MustBeANonZeroAddress();

        address multisig = ConfigStorage.layout().multisigContract;
        if (multisig == address(0)) revert MustBeANonZeroAddress();

        MostroFactoryLayout storage s = MostroFactoryStorage.layout();
        if (s.artistTokens[artistId] != address(0)) revert ArtistAlreadyExists();

        if (IERC20(tokenAddress).balanceOf(address(this)) < totalSupply) revert InsufficientTokenBalance();

        s.artistTokens[artistId] = tokenAddress;
        s.artistCount++;

        uint256 publicPoolAlloc  = (totalSupply * PUBLIC_POOL_BPS) / 10000;
        uint256 streamflowAlloc  = (totalSupply * STREAMFLOW_ESCROW_BPS) / 10000;
        uint256 lpAlloc          = (totalSupply * LP_BPS) / 10000;
        uint256 genesisAlloc     = totalSupply - publicPoolAlloc - streamflowAlloc - lpAlloc;

        _deployPublicPoolVault(tokenAddress, publicPoolAlloc, publicPoolHotVault, s, multisig);
        _deployStreamflowEscrowVault(tokenAddress, streamflowAlloc, streamflowHotVault, s, multisig);
        _deployLPVault(tokenAddress, lpAlloc, lpHotVault, s, multisig);
        _deployGenesisVault(tokenAddress, genesisAlloc, genesisHotVault, s, multisig);
    }

    // ─── View Functions ───────────────────────────────────

    /**
     * @notice Returns the ERC20 token address registered for `artistId`.
     * @return Zero address if the artist has not been initialized.
     */
    function getArtistToken(string calldata artistId) external view returns (address) {
        return MostroFactoryStorage.layout().artistTokens[artistId];
    }

    /**
     * @notice Returns the {PublicPoolVault} address for a given artist token.
     * @return Zero address if the artist has not been initialized.
     */
    function getPublicPoolVault(address tokenAddress) external view returns (address) {
        return MostroFactoryStorage.layout().publicPoolVaults[tokenAddress];
    }

    /**
     * @notice Returns the {StreamflowEscrowVault} address for a given artist token.
     * @return Zero address if the artist has not been initialized.
     */
    function getStreamflowEscrowVault(address tokenAddress) external view returns (address) {
        return MostroFactoryStorage.layout().streamflowEscrowVaults[tokenAddress];
    }

    /**
     * @notice Returns the {LPVault} address for a given artist token.
     * @return Zero address if the artist has not been initialized.
     */
    function getLPVault(address tokenAddress) external view returns (address) {
        return MostroFactoryStorage.layout().lpVaults[tokenAddress];
    }

    /**
     * @notice Returns the {GenesisVault} address for a given artist token.
     * @return Zero address if the artist has not been initialized.
     */
    function getGenesisVault(address tokenAddress) external view returns (address) {
        return MostroFactoryStorage.layout().genesisVaults[tokenAddress];
    }

    // ─── Internal Helpers ─────────────────────────────────

    /**
     * @dev Deploys a {PublicPoolVault}, transfers `allocation` tokens to it, and persists
     *      vault address, allocation amount, and intended hot vault in Diamond storage.
     *      Reverts with {VaultCreationFailed} if the ERC20 transfer returns false.
     *      Emits {PublicPoolVaultCreated}.
     * @param tokenAddress Artist ERC20 token address.
     * @param allocation   Token amount to transfer to the vault, in base units.
     * @param hotVault     Intended downstream destination, registered for multisig reference.
     * @param s            Reference to the Diamond factory storage layout.
     * @param multisig     Address assigned as the vault's sole release controller.
     */
    function _deployPublicPoolVault(
        address tokenAddress,
        uint256 allocation,
        address hotVault,
        MostroFactoryLayout storage s,
        address multisig
    ) internal {
        address vaultAddress = address(new PublicPoolVault(tokenAddress, multisig));
        if (!IERC20(tokenAddress).transfer(vaultAddress, allocation)) revert VaultCreationFailed();

        s.publicPoolVaults[tokenAddress] = vaultAddress;
        s.publicPoolAllocations[tokenAddress] = allocation;
        s.publicPoolHotVaults[tokenAddress] = hotVault;

        emit PublicPoolVaultCreated(tokenAddress, vaultAddress);
    }

    /**
     * @dev Deploys a {StreamflowEscrowVault}, transfers `allocation` tokens to it, and persists
     *      vault address, allocation amount, and intended hot vault in Diamond storage.
     *      Reverts with {VaultCreationFailed} if the ERC20 transfer returns false.
     *      Emits {StreamflowEscrowVaultCreated}.
     * @param tokenAddress Artist ERC20 token address.
     * @param allocation   Token amount to transfer to the vault, in base units.
     * @param hotVault     Intended downstream destination, registered for multisig reference.
     * @param s            Reference to the Diamond factory storage layout.
     * @param multisig     Address assigned as the vault's sole release controller.
     */
    function _deployStreamflowEscrowVault(
        address tokenAddress,
        uint256 allocation,
        address hotVault,
        MostroFactoryLayout storage s,
        address multisig
    ) internal {
        address vaultAddress = address(new StreamflowEscrowVault(tokenAddress, multisig));
        if (!IERC20(tokenAddress).transfer(vaultAddress, allocation)) revert VaultCreationFailed();

        s.streamflowEscrowVaults[tokenAddress] = vaultAddress;
        s.streamflowEscrowAllocations[tokenAddress] = allocation;
        s.streamflowHotVaults[tokenAddress] = hotVault;

        emit StreamflowEscrowVaultCreated(tokenAddress, vaultAddress);
    }

    /**
     * @dev Deploys a {LPVault}, transfers `allocation` tokens to it, and persists
     *      vault address, allocation amount, and intended hot vault in Diamond storage.
     *      Reverts with {VaultCreationFailed} if the ERC20 transfer returns false.
     *      Emits {LPVaultCreated}.
     * @param tokenAddress Artist ERC20 token address.
     * @param allocation   Token amount to transfer to the vault, in base units.
     * @param hotVault     Intended downstream destination, registered for multisig reference.
     * @param s            Reference to the Diamond factory storage layout.
     * @param multisig     Address assigned as the vault's sole release controller.
     */
    function _deployLPVault(
        address tokenAddress,
        uint256 allocation,
        address hotVault,
        MostroFactoryLayout storage s,
        address multisig
    ) internal {
        address vaultAddress = address(new LPVault(tokenAddress, multisig));
        if (!IERC20(tokenAddress).transfer(vaultAddress, allocation)) revert VaultCreationFailed();

        s.lpVaults[tokenAddress] = vaultAddress;
        s.lpAllocations[tokenAddress] = allocation;
        s.lpHotVaults[tokenAddress] = hotVault;

        emit LPVaultCreated(tokenAddress, vaultAddress);
    }

    /**
     * @dev Deploys a {GenesisVault}, transfers `allocation` tokens to it, and persists
     *      vault address, allocation amount, and intended hot vault in Diamond storage.
     *      `allocation` is the arithmetic remainder after the three prior vaults, ensuring
     *      the Diamond holds zero tokens of `tokenAddress` after this call.
     *      Reverts with {VaultCreationFailed} if the ERC20 transfer returns false.
     *      Emits {GenesisVaultCreated}.
     * @param tokenAddress Artist ERC20 token address.
     * @param allocation   Token amount to transfer to the vault, in base units.
     * @param hotVault     Intended downstream destination, registered for multisig reference.
     * @param s            Reference to the Diamond factory storage layout.
     * @param multisig     Address assigned as the vault's sole release controller.
     */
    function _deployGenesisVault(
        address tokenAddress,
        uint256 allocation,
        address hotVault,
        MostroFactoryLayout storage s,
        address multisig
    ) internal {
        address vaultAddress = address(new GenesisVault(tokenAddress, multisig));
        if (!IERC20(tokenAddress).transfer(vaultAddress, allocation)) revert VaultCreationFailed();

        s.genesisVaults[tokenAddress] = vaultAddress;
        s.genesisAllocations[tokenAddress] = allocation;
        s.genesisHotVaults[tokenAddress] = hotVault;

        emit GenesisVaultCreated(tokenAddress, vaultAddress);
    }
}
