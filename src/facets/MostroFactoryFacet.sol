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

contract MostroFactoryFacet is IMostroStructs, IMostroFactory {

    // ─── Constants ────────────────────────────────────────

    uint256 public constant PUBLIC_POOL_BPS        = 4500;
    uint256 public constant STREAMFLOW_ESCROW_BPS  = 4700;
    uint256 public constant LP_BPS                 = 500;
    uint256 public constant GENESIS_BPS            = 10000 - PUBLIC_POOL_BPS - STREAMFLOW_ESCROW_BPS - LP_BPS;

    // ─── Modifiers ────────────────────────────────────────

    modifier onlyAdminOrSuperAdmin() {
        MostroRoleManagerLayout storage roles = MostroRoleManagerStorage.layout();
        if (!roles.admins[msg.sender] && !roles.superAdmins[msg.sender]) revert Unauthorized();
        _;
    }

    // ─── Factory Functions ─────────────────────────────────

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

    function getArtistToken(string calldata artistId) external view returns (address) {
        return MostroFactoryStorage.layout().artistTokens[artistId];
    }

    function getPublicPoolVault(address tokenAddress) external view returns (address) {
        return MostroFactoryStorage.layout().publicPoolVaults[tokenAddress];
    }

    function getStreamflowEscrowVault(address tokenAddress) external view returns (address) {
        return MostroFactoryStorage.layout().streamflowEscrowVaults[tokenAddress];
    }

    function getLPVault(address tokenAddress) external view returns (address) {
        return MostroFactoryStorage.layout().lpVaults[tokenAddress];
    }

    function getGenesisVault(address tokenAddress) external view returns (address) {
        return MostroFactoryStorage.layout().genesisVaults[tokenAddress];
    }

    // ─── Internal Helpers ─────────────────────────────────

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
