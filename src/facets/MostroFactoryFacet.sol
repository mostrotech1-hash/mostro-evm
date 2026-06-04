// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IMostroFactory} from '../interfaces/IMostroFactory.sol';
import {IMostroStructs} from '../interfaces/IMostroStructs.sol';
import {MostroFactoryStorage, MostroRoleManagerStorage, ConfigStorage, ReentrancyStorage} from '../libraries/StorageLibraries.sol';
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

    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED     = 2;

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
     * @dev Diamond-compatible reentrancy guard. Uses a dedicated keccak256 storage slot
     *      to avoid collisions with other facets. Status is initialised to NOT_ENTERED (1)
     *      on first read (default uint256 is 0, treated as NOT_ENTERED).
     */
    modifier nonReentrant() {
        ReentrancyLayout storage r = ReentrancyStorage.layout();
        if (r.status == ENTERED) revert ReentrantCall();
        r.status = ENTERED;
        _;
        r.status = NOT_ENTERED;
    }

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
     * @dev Callable once per `artistId`. `totalSupply` is validated against the token's on-chain
     *      `totalSupply()` to prevent misconfiguration. Allocation order is fixed: public pool →
     *      streamflow → LP → genesis. The genesis vault always receives the exact arithmetic
     *      remainder, capturing any integer division dust to guarantee `sum(allocations) == totalSupply`.
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
    ) external onlyAdminOrSuperAdmin nonReentrant {
        if (bytes(artistId).length == 0) revert InvalidArtistId();
        if (totalSupply == 0) revert InvalidTotalSupply();
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

        if (IERC20(tokenAddress).totalSupply() != totalSupply) revert TotalSupplyMismatch();
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

    /// @dev Thin wrapper — deploys the vault contract then delegates to {_fundAndRegisterVault}.
    function _deployPublicPoolVault(address tokenAddress, uint256 allocation, address hotVault, MostroFactoryLayout storage s, address multisig) internal {
        address vaultAddress = address(new PublicPoolVault(tokenAddress, multisig));
        _fundAndRegisterVault(vaultAddress, tokenAddress, allocation, hotVault, s.publicPoolVaults, s.publicPoolAllocations, s.publicPoolHotVaults);
        emit PublicPoolVaultCreated(tokenAddress, vaultAddress);
    }

    /// @dev Thin wrapper — deploys the vault contract then delegates to {_fundAndRegisterVault}.
    function _deployStreamflowEscrowVault(address tokenAddress, uint256 allocation, address hotVault, MostroFactoryLayout storage s, address multisig) internal {
        address vaultAddress = address(new StreamflowEscrowVault(tokenAddress, multisig));
        _fundAndRegisterVault(vaultAddress, tokenAddress, allocation, hotVault, s.streamflowEscrowVaults, s.streamflowEscrowAllocations, s.streamflowHotVaults);
        emit StreamflowEscrowVaultCreated(tokenAddress, vaultAddress);
    }

    /// @dev Thin wrapper — deploys the vault contract then delegates to {_fundAndRegisterVault}.
    function _deployLPVault(address tokenAddress, uint256 allocation, address hotVault, MostroFactoryLayout storage s, address multisig) internal {
        address vaultAddress = address(new LPVault(tokenAddress, multisig));
        _fundAndRegisterVault(vaultAddress, tokenAddress, allocation, hotVault, s.lpVaults, s.lpAllocations, s.lpHotVaults);
        emit LPVaultCreated(tokenAddress, vaultAddress);
    }

    /// @dev Thin wrapper — deploys the vault contract then delegates to {_fundAndRegisterVault}.
    ///      `allocation` is the arithmetic remainder, ensuring the Diamond holds zero tokens after this call.
    function _deployGenesisVault(address tokenAddress, uint256 allocation, address hotVault, MostroFactoryLayout storage s, address multisig) internal {
        address vaultAddress = address(new GenesisVault(tokenAddress, multisig));
        _fundAndRegisterVault(vaultAddress, tokenAddress, allocation, hotVault, s.genesisVaults, s.genesisAllocations, s.genesisHotVaults);
        emit GenesisVaultCreated(tokenAddress, vaultAddress);
    }

    /**
     * @dev Shared logic for all cold vault deployments: transfers tokens and writes three
     *      storage entries. Extracted to eliminate duplication across the four deploy wrappers.
     *      Reverts with {VaultCreationFailed} if the ERC20 transfer returns false.
     * @param vaultAddress   Deployed cold vault address, recipient of the token transfer.
     * @param tokenAddress   Artist ERC20 token address.
     * @param allocation     Token amount to transfer, in base units.
     * @param hotVault       Intended downstream destination, registered for multisig reference.
     * @param vaultMap       Diamond storage mapping: token → vault address.
     * @param allocationMap  Diamond storage mapping: token → allocated amount.
     * @param hotVaultMap    Diamond storage mapping: token → intended hot vault.
     */
    function _fundAndRegisterVault(
        address vaultAddress,
        address tokenAddress,
        uint256 allocation,
        address hotVault,
        mapping(address => address) storage vaultMap,
        mapping(address => uint256) storage allocationMap,
        mapping(address => address) storage hotVaultMap
    ) internal {
        if (!IERC20(tokenAddress).transfer(vaultAddress, allocation)) revert VaultCreationFailed();
        vaultMap[tokenAddress] = vaultAddress;
        allocationMap[tokenAddress] = allocation;
        hotVaultMap[tokenAddress] = hotVault;
    }
}
