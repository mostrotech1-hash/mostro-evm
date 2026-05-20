// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MostroRoleManagerStorage} from '../libraries/StorageLibraries.sol';

interface IArtistFacet {

    // ─── Events ───────────────────────────────────────────

    event ArtistCreated(
        uint256 indexed artistId,
        string  artistName,
        address indexed tokenAddress,
        uint256 totalSupply,
        uint256 createdTimestamp
    );

    event ArtistActivated(uint256 indexed artistId);

    // ─── Errors ───────────────────────────────────────────

    error NotAuthorized();
    error ZeroSupply();
    error EmptyArtistName();
    error EmptyTokenName();
    error EmptyTokenSymbol();
    error ArtistNameAlreadyExists(string name);
    error TokenAlreadyExists(address token);
    error ArtistNotFound(uint256 artistId);
    error ArtistAlreadyActive(uint256 artistId);
    error DiamondBalanceNotZero(address token, uint256 remaining);

    // ─── Artist Creation ──────────────────────────────────

    /// @notice Creates an artist, deploys their ERC20 token, and
    ///         orchestrates hot and cold vault setup.
    /// @param _artistName          Display name of the artist.
    /// @param _tokenName           ERC20 token name.
    /// @param _tokenSymbol         ERC20 token symbol.
    /// @param _totalSupply         Fixed total supply — minted once to Diamond.
    /// @param _beneficiaryWallet   Optional artist wallet for vesting/revenue flows.
    ///                             Pass address(0) if not applicable.
    function createArtist(
        string  calldata _artistName,
        string  calldata _tokenName,
        string  calldata _tokenSymbol,
        uint256 _totalSupply,
        address _beneficiaryWallet
    ) external;

    // ─── Queries ──────────────────────────────────────────

    function getArtistById(
        uint256 _artistId
    ) external view returns (ArtistStorage.ArtistRecord memory);

    function getArtistIdByToken(
        address _token
    ) external view returns (uint256);

    function getArtistCount()
        external view returns (uint256);

    function isArtistActive(
        uint256 _artistId
    ) external view returns (bool);

    function getVaultsByArtistId(
        uint256 _artistId
    ) external view returns (ArtistStorage.VaultAddresses memory);
}

