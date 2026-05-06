// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TokenFactoryStorage} from "../libraries/StorageLibraries.sol";

interface ITokenFactory {

    // ─── Events ───────────────────────────────────────────

    event TokenLaunched(
        address indexed tokenAddress,
        address indexed artistWallet,
        uint256 totalSupply,
        uint256 launchTimestamp
    );

    // ─── Errors ───────────────────────────────────────────

    error ZeroAddress();
    error ZeroSupply();
    error TokenAlreadyLaunched(address token);
    error DistributionFailed();
    error RemainingBalanceAfterDistribution();
    error EmptyName();
    error EmptySymbol();

    // ─── Launch ───────────────────────────────────────────

    function launchArtistToken(
        string calldata _name,
        string calldata _symbol,
        uint256 _totalSupply,
        address _artistWallet,
        address _multisig,
        address _usdc
    ) external;

    // ─── Queries ──────────────────────────────────────────

    function getTokenRecord(
        address _token
    ) external view returns (TokenFactoryStorage.TokenRecord memory);

    function getTokensByArtist(
        address _artist
    ) external view returns (address[] memory);

    function getArtistByToken(
        address _token
    ) external view returns (address);

    function getVaultsByToken(
        address _token
    ) external view returns (TokenFactoryStorage.VaultAddresses memory);

    function getAllLaunchedTokens()
        external view returns (address[] memory);
}