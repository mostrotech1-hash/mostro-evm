// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IMostroFactory} from '../interfaces/IMostroFactory.sol';
import {IMostroStructs} from '../interfaces/IMostroStructs.sol';
import {MostroFactoryStorage, MostroRoleManagerStorage} from '../libraries/StorageLibraries.sol';
import {MostroArtistToken} from '../MostroArtistToken.sol';
import {PublicPoolVault} from '../vaults/PublicPoolVault.sol';
import {StreamflowEscrowVault} from '../vaults/StreamflowEscrowVault.sol';
import {LPVault} from '../vaults/LPVault.sol';
import {GenesisVault} from '../vaults/GenesisVault.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/**
 * @title MostroFactoryFacet
 * @dev A facet that manages the creation of new MostroArtistTokens and their associated vaults.
 */
contract MostroFactoryFacet is IMostroStructs, IMostroFactory {

    // ─── Constants ────────────────────────────────────────

    uint256 public constant ARTIST_TOKEN_SUPPLY          = 1_000_000_000 * 10 ** 18;
    uint256 public constant PUBLIC_POOL_ALLOCATION        = 45;
    uint256 public constant STREAMFLOW_ESCROW_ALLOCATION  = 47;
    uint256 public constant LP_ALLOCATION                 = 5;

    // ─── Modifiers ────────────────────────────────────────

    modifier onlyAdmin() {
        MostroRoleManagerLayout storage roles = MostroRoleManagerStorage.layout();
        if (!roles.admins[msg.sender] && !roles.superAdmins[msg.sender]) revert Unauthorized();
        _;
    }

    // ─── Factory Functions ─────────────────────────────────

    function createArtistToken(
        string calldata artistName,
        string calldata symbol
    ) external onlyAdmin returns (address) {
        if (bytes(artistName).length == 0) revert InvalidArtistName();

        MostroFactoryLayout storage s = MostroFactoryStorage.layout();
        if (s.artistTokens[artistName] != address(0)) revert ArtistAlreadyExists();

        MostroArtistToken token = new MostroArtistToken(address(this));
        address tokenAddress = address(token);
        if (tokenAddress == address(0)) revert TokenCreationFailed();

        token.initialize(artistName, symbol, ARTIST_TOKEN_SUPPLY, address(this));

        s.artistTokens[artistName] = tokenAddress;
        s.artistCount++;

        emit ArtistTokenCreated(artistName, tokenAddress);

        _deployPublicPoolVault(tokenAddress, s);
        _deployStreamflowEscrowVault(tokenAddress, s);
        _deployLPVault(tokenAddress, s);
        _deployGenesisVault(tokenAddress, s);

        return tokenAddress;
    }

    // ─── View Functions ───────────────────────────────────

    function getArtistToken(string calldata artistName) external view returns (address) {
        return MostroFactoryStorage.layout().artistTokens[artistName];
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

    function _deployPublicPoolVault(address tokenAddress, MostroFactoryLayout storage s) internal returns (address) {
        address vaultAddress = address(new PublicPoolVault(tokenAddress, address(this)));
        uint256 allocation = (IERC20(tokenAddress).totalSupply() * PUBLIC_POOL_ALLOCATION) / 100;
        if (!IERC20(tokenAddress).transfer(vaultAddress, allocation)) revert VaultCreationFailed();

        s.publicPoolVaults[tokenAddress] = vaultAddress;
        emit PublicPoolVaultCreated(tokenAddress, vaultAddress);
        return vaultAddress;
    }

    function _deployStreamflowEscrowVault(address tokenAddress, MostroFactoryLayout storage s) internal returns (address) {
        address vaultAddress = address(new StreamflowEscrowVault(tokenAddress, address(this)));
        uint256 allocation = (IERC20(tokenAddress).totalSupply() * STREAMFLOW_ESCROW_ALLOCATION) / 100;
        if (!IERC20(tokenAddress).transfer(vaultAddress, allocation)) revert VaultCreationFailed();

        s.streamflowEscrowVaults[tokenAddress] = vaultAddress;
        emit StreamflowEscrowVaultCreated(tokenAddress, vaultAddress);
        return vaultAddress;
    }

    function _deployGenesisVault(address tokenAddress, MostroFactoryLayout storage s) internal returns (address) {
        address vaultAddress = address(new GenesisVault(tokenAddress, address(this)));
        uint256 remaining = IERC20(tokenAddress).balanceOf(address(this));
        if (!IERC20(tokenAddress).transfer(vaultAddress, remaining)) revert VaultCreationFailed();

        s.genesisVaults[tokenAddress] = vaultAddress;
        emit GenesisVaultCreated(tokenAddress, vaultAddress);
        return vaultAddress;
    }

    function _deployLPVault(address tokenAddress, MostroFactoryLayout storage s) internal returns (address) {
        address vaultAddress = address(new LPVault(tokenAddress, address(this)));
        uint256 allocation = (IERC20(tokenAddress).totalSupply() * LP_ALLOCATION) / 100;
        if (!IERC20(tokenAddress).transfer(vaultAddress, allocation)) revert VaultCreationFailed();

        s.lpVaults[tokenAddress] = vaultAddress;
        emit LPVaultCreated(tokenAddress, vaultAddress);
        return vaultAddress;
    }
}
