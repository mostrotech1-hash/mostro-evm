// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMostroFactory {

    // ─── Events ───────────────────────────────────────────

    event PublicPoolVaultCreated(address indexed tokenAddress, address indexed vaultAddress);
    event StreamflowEscrowVaultCreated(address indexed tokenAddress, address indexed vaultAddress);
    event LPVaultCreated(address indexed tokenAddress, address indexed vaultAddress);
    event GenesisVaultCreated(address indexed tokenAddress, address indexed vaultAddress);

    // ─── Errors ───────────────────────────────────────────

    error MustBeANonZeroAddress();
    error InvalidArtistId();
    error ArtistAlreadyExists();
    error VaultCreationFailed();
    error InsufficientTokenBalance();
    error TotalSupplyMismatch();
    error Unauthorized();

    // ─── Factory Functions ─────────────────────────────────

    function initializeColdVaults(
        string calldata artistId,
        address tokenAddress,
        uint256 totalSupply,
        address publicPoolHotVault,
        address streamflowHotVault,
        address lpHotVault,
        address genesisHotVault
    ) external;

    // ─── View Functions ───────────────────────────────────

    function getArtistToken(string calldata artistId) external view returns (address);
    function getPublicPoolVault(address tokenAddress) external view returns (address);
    function getStreamflowEscrowVault(address tokenAddress) external view returns (address);
    function getLPVault(address tokenAddress) external view returns (address);
    function getGenesisVault(address tokenAddress) external view returns (address);

}
