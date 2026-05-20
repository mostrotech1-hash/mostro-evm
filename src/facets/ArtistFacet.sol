// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IArtistFacet}       from "../Interfaces/IArtistFacet.sol";
import {ArtistStorage}      from "../libraries/StorageLibraries.sol";
import {MostroRoleManagerStorage} from '../libraries/StorageLibraries.sol';
import {ArtistToken}        from "../MostroArtistToken.sol";
import {IERC20}             from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ArtistFacet is IArtistFacet {

    // ─── Modifiers ────────────────────────────────────────

    modifier onlyAdminOrSuperAdmin() {
        MostroRoleManagerStorage.MostroRoleManagerLayout storage r =
            MostroRoleManagerStorage.layout();
        if (!r.superAdmins[msg.sender] && !r.admins[msg.sender])
            revert NotAuthorized();
        _;
    }

    // ─── Artist Creation ──────────────────────────────────

    function createArtist(
        string  calldata _artistName,
        string  calldata _tokenName,
        string  calldata _tokenSymbol,
        uint256 _totalSupply,
        address _beneficiaryWallet
    ) external onlyAdminOrSuperAdmin {

        // ── Input validation ──────────────────────────────
        if (bytes(_artistName).length == 0)  revert EmptyArtistName();
        if (bytes(_tokenName).length == 0)   revert EmptyTokenName();
        if (bytes(_tokenSymbol).length == 0) revert EmptyTokenSymbol();
        if (_totalSupply == 0)               revert ZeroSupply();

        ArtistStorage.ArtistStorageLayout storage artist = ArtistStorage.layout();

        // ── Duplicate artist name guard ───────────────────
        bytes32 nameHash = keccak256(bytes(_artistName));
        if (artist.artistIdByNameHash[nameHash] != 0)
            revert ArtistNameAlreadyExists(_artistName); 

        // ── Generate artist ID ────────────────────────────
        artist.artistCount++;
        uint256 artistId = artist.artistCount;

        // ── Deploy artist token ───────────────────────────
        // Full supply is minted to Diamond (address(this)) inside constructor
        ArtistToken token = new ArtistToken(
            _tokenName,
            _tokenSymbol,
            _totalSupply,
            address(this)
        );
        address tokenAddress = address(token);

        // Duplicate token guard
        if (artist.artistIdByToken[tokenAddress] != 0)
            revert TokenAlreadyExists(tokenAddress);

        // ── Verify Diamond received full supply ───────────
        // Future minting is disabled — ArtistToken has no mint function
        // beyond the constructor, so supply is fixed from this point.
        uint256 diamondBalance = IERC20(tokenAddress).balanceOf(address(this));
        require(diamondBalance == _totalSupply, "Mint verification failed");

        // ── TODO: Call Hot Vault Facet ────────────────────
        

        // ── TODO: Call Cold Vault Facet ───────────────────

        // ── TODO: Verify Diamond balance is zero ──────────

        // ── Write storage ─────────────────────────────────
        ArtistStorage.VaultAddresses memory vaultAddresses = ArtistStorage.VaultAddresses({
            hotVaults:  hotVaults,
            coldVaults: coldVaults
        });

        artist.artistsById[artistId] = ArtistStorage.ArtistRecord({
            artistId:          artistId,
            artistName:        _artistName,
            tokenName:         _tokenName,
            tokenSymbol:       _tokenSymbol,
            tokenAddress:      tokenAddress,
            totalSupply:       _totalSupply,
            beneficiaryWallet: _beneficiaryWallet,
            vaults:            vaultAddresses,
            createdTimestamp:  block.timestamp,
            active:            false  // activated after full setup succeeds
        });

        artist.artistIdByToken[tokenAddress] = artistId;
        artist.artistIdByNameHash[nameHash]  = artistId;

        // ── Activate artist ───────────────────────────────
        // TODO: move _activateArtist call to after cold vault integration
        // confirms Diamond balance is zero. Uncomment the line below
        // and remove the current call once cold vault facet is ready.
        _activateArtist(artist, artistId);

        emit ArtistCreated(
            artistId,
            _artistName,
            tokenAddress,
            _totalSupply,
            block.timestamp
        );
    }

    // ─── Internal ─────────────────────────────────────────

    function _activateArtist(
        ArtistStorage.ArtistStorageLayout storage artist,
        uint256 _artistId
    ) internal {
        if (artist.artistsById[_artistId].artistId == 0) revert ArtistNotFound(_artistId);
        if (artist.artistsById[_artistId].active) revert ArtistAlreadyActive(_artistId);

        artist.artistsById[_artistId].active = true;
        emit ArtistActivated(_artistId);
    }

    // ─── Queries ──────────────────────────────────────────

    function getArtistById(
        uint256 _artistId
    ) external view returns (ArtistStorage.ArtistRecord memory) {
        return ArtistStorage.layout().artistsById[_artistId];
    }

    function getArtistIdByToken(
        address _token
    ) external view returns (uint256) {
        return ArtistStorage.layout().artistIdByToken[_token];
    }

    function getArtistCount()
        external view returns (uint256) {
        return ArtistStorage.layout().artistCount;
    }

    function isArtistActive(
        uint256 _artistId
    ) external view returns (bool) {
        return ArtistStorage.layout().artistsById[_artistId].active;
    }

    function getVaultsByArtistId(
        uint256 _artistId
    ) external view returns (ArtistStorage.VaultAddresses memory) {
        return ArtistStorage.layout().artistsById[_artistId].vaults;
    }
}