// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMostroFactory {

    // ─── Events ───────────────────────────────────────────

    event ArtistTokenCreated(string indexed artistName, address indexed tokenAddress);
    event PublicPoolVaultCreated(address indexed tokenAddress, address indexed vaultAddress);
    event StreamflowEscrowVaultCreated(address indexed tokenAddress, address indexed vaultAddress);
    event LPVaultCreated(address indexed tokenAddress, address indexed vaultAddress);
    event GenesisVaultCreated(address indexed tokenAddress, address indexed vaultAddress);

    // ─── Errors ───────────────────────────────────────────

    error MustBeANonZeroAddress();
    error InvalidArtistName();
    error ArtistAlreadyExists();
    error ArtistDoesNotExist();
    error TokenCreationFailed();
    error VaultCreationFailed();
    error Unauthorized();

    // ─── Factory Functions ─────────────────────────────────

    function createArtistToken(string calldata artistName, string calldata symbol) external returns (address);

    // ─── View Functions ───────────────────────────────────

    function getArtistToken(string calldata artistName) external view returns (address);
    function getPublicPoolVault(address tokenAddress) external view returns (address);
    function getStreamflowEscrowVault(address tokenAddress) external view returns (address);
    function getLPVault(address tokenAddress) external view returns (address);
    function getGenesisVault(address tokenAddress) external view returns (address);

}