// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title  ArtistUnvestedVault
/// @notice Receives vested tokens from StreamFlowEscrowVault on schedule.
///         Artist wallet is the sole owner and can move tokens out.
contract ArtistUnvestedVault is ReentrancyGuard {
    string public constant VAULT_NAME = "ArtistUnvestedVault";

    using SafeERC20 for IERC20;

    address public immutable ARTIST;
    IERC20 public immutable TOKEN;
    address public immutable FROM_STREAM_FLOW_CONTRACT;

    uint256 public totalReceived;
    uint256 public totalReleased;

    error NotArtist();
    error ZeroAddress();
    error NotContract();
    error InvalidAmount();
    error InsufficientBalance();

    /// EVENTS
    event TOKENReceived(
        address indexed from,
        uint256 amount,
        uint256 newBalance
    );
    event TOKENReleased(
        address indexed recipient,
        uint256 amount,
        uint256 newBalance
    );

    /*
     * Sets immutable addresses:
     * - TOKEN: vested token contract.
     * - ARTIST: only account allowed to release tokens.
     * - FROM_STREAM_FLOW_CONTRACT: only contract allowed to fund this vault.
     */
    constructor(address _token, address _artist, address _contract) {
        if (_contract == address(0)) revert ZeroAddress();
        if (_token == address(0)) revert ZeroAddress();
        if (_artist == address(0)) revert ZeroAddress();

        ARTIST = _artist;
        TOKEN = IERC20(_token);
        FROM_STREAM_FLOW_CONTRACT = _contract;
    }

    /*
     * Pulls TOKEN from StreamFlowEscrowVault into this vault.
     * Token flow: `msg.sender` (stream flow vault) -> `address(this)`.
     * Callable only by `FROM_STREAM_FLOW_CONTRACT`.
     */
    function receiveFromStreamFlow(uint256 amount) external onlyContract nonReentrant {
        if (amount == 0) revert InvalidAmount();

        TOKEN.safeTransferFrom(msg.sender, address(this), amount);

        totalReceived += amount;

        emit TOKENReceived(msg.sender, amount, TOKEN.balanceOf(address(this)));
    }

    /*
     * Artist-controlled token release to any recipient.
     * Token flow: `address(this)` -> `recipient`.
     */
    function release(address recipient, uint256 amount) external onlyArtist nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();

        uint256 balance = TOKEN.balanceOf(address(this));
        if (amount > balance) revert InsufficientBalance();

        totalReleased += amount;
        TOKEN.safeTransfer(recipient, amount);

        emit TOKENReleased(recipient, amount, TOKEN.balanceOf(address(this)));
    }

    /*
     * Returns TOKEN balance currently stored in this vault.
     */
    function vaultBalance() external view returns (uint256) {
        return TOKEN.balanceOf(address(this));
    }

    /*
     * Restricts execution to ARTIST.
     */
    modifier onlyArtist() {
        _onlyArtist();
        _;
    }

    /*
     * Restricts execution to FROM_STREAM_FLOW_CONTRACT.
     */
    modifier onlyContract() {
        _onlyContract();
        _;
    }

    /*
     * Reverts unless caller is ARTIST.
     */
    function _onlyArtist() internal view {
        if (msg.sender != ARTIST) revert NotArtist();
    }

    /*
     * Reverts unless caller is the configured stream flow contract.
     */
    function _onlyContract() internal view {
        if (msg.sender != FROM_STREAM_FLOW_CONTRACT) revert NotContract();
    }
}
