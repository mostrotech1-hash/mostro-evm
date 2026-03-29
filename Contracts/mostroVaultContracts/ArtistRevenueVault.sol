// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title ArtistRevenueVault
/// @notice Artist-owned USDC revenue vault. Only the artist can release funds.
/// @dev Public `deposit` is front-runnable by design (first depositor / ordering); use commit-reveal or
///      off-chain coordination if strict ordering is required.
contract ArtistRevenueVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    string public constant VAULT_NAME = "ArtistRevenueVault";

    address public immutable ARTIST;
    IERC20 public immutable USDC;

    uint256 public totalReceived;
    uint256 public totalReleased;

    error NotArtist();
    error ZeroAddress();
    error InvalidAmount();
    error InsufficientBalance();

    event RevenueReceived(
        address indexed from,
        uint256 amount,
        uint256 newBalance
    );
    event RevenueReleased(
        address indexed recipient,
        uint256 amount,
        uint256 newBalance
    );

    /*
     * Configures immutable USDC token and ARTIST owner address.
     */
    constructor(address usdc, address artist) {
        if (usdc == address(0)) revert ZeroAddress();
        if (artist == address(0)) revert ZeroAddress();

        USDC = IERC20(usdc);
        ARTIST = artist;
    }

    /*
     * Pulls USDC from caller into this revenue vault.
     * Token flow: `msg.sender` -> `address(this)`.
     * Caller must approve this vault before calling.
     */
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();

        USDC.safeTransferFrom(msg.sender, address(this), amount);
        totalReceived += amount;

        emit RevenueReceived(msg.sender, amount, USDC.balanceOf(address(this)));
    }

    /*
     * Artist-controlled USDC withdrawal.
     * Token flow: `address(this)` -> `recipient`.
     */
    function release(address recipient, uint256 amount) external onlyArtist nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();

        uint256 balance = USDC.balanceOf(address(this));
        if (amount > balance) revert InsufficientBalance();

        totalReleased += amount;
        USDC.safeTransfer(recipient, amount);

        emit RevenueReleased(recipient, amount, USDC.balanceOf(address(this)));
    }

    /*
     * Returns current USDC balance held by this vault.
     */
    function vaultBalance() external view returns (uint256) {
        return USDC.balanceOf(address(this));
    }

    /*
     * Restricts function execution to ARTIST.
     */
    modifier onlyArtist() {
        if (msg.sender != ARTIST) revert NotArtist();
        _;
    }
}
