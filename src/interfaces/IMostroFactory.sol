// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMostroFactory {

    // ─── Events ───────────────────────────────────────────

    event ArtistTokenCreated(string indexed artistName, address indexed tokenAddress);
    event PublicPoolVaultCreated(address indexed tokenAddress, address indexed vaultAddress);
    event StreamflowEscrowVaultCreated(address indexed tokenAddress, address indexed vaultAddress);
    event LPVaultCreated(address indexed tokenAddress, address indexed vaultAddress);

    // ─── Errors ───────────────────────────────────────────

    error MustBeANonZeroAddress();
    error ArtistAlreadyExists();
    error ArtistDoesNotExist();
    error TokenCreationFailed();
    error VaultCreationFailed();

    // ─── Factory Functions ─────────────────────────────────

    function createArtistToken(string calldata artistName) external returns (address);
    function createPublicPoolVault(address tokenAddress) external returns (address);
    function createStreamflowEscrowVault(address tokenAddress) external returns (address);
    function createLPVault(address tokenAddress) external returns (address);

    // ─── View Functions ───────────────────────────────────

    function getArtistToken(string calldata artistName) external view returns (address);
    function getPublicPoolVault(address tokenAddress) external view returns (address);
    function getStreamflowEscrowVault(address tokenAddress) external view returns (address);
    function getLPVault(address tokenAddress) external view returns (address);

}