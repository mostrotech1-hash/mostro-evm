// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ArtistUnvestedVault
 * @dev Hot vault that receives tokens from StreamflowEscrowVault.
 *      Holds unvested artist tokens pending Streamflow integration.
 */
contract ArtistUnvestedVault {

    // ─── State Variables ──────────────────────────────────

    address public immutable artistToken;
    address public immutable diamond;
    address public artist;

    // ─── Events ───────────────────────────────────────────

    event ArtistSet(address indexed artist);

    // ─── Errors ───────────────────────────────────────────

    error MustBeANonZeroAddress();
    error OnlyDiamond();
    error ArtistAlreadySet();

    // ─── Modifier ─────────────────────────────────────────

    modifier onlyDiamond() {
        if (msg.sender != diamond) revert OnlyDiamond();
        _;
    }

    // ─── Constructor ──────────────────────────────────────

    constructor(address _artistToken, address _diamond) {
        if (_artistToken == address(0) || _diamond == address(0)) revert MustBeANonZeroAddress();
        artistToken = _artistToken;
        diamond = _diamond;
    }

    // ─── Diamond Functions ────────────────────────────────

    function setArtist(address _artist) external onlyDiamond {
        if (_artist == address(0)) revert MustBeANonZeroAddress();
        if (artist != address(0)) revert ArtistAlreadySet();
        artist = _artist;
        emit ArtistSet(_artist);
    }

    // ─── View Functions ───────────────────────────────────

    function balance() external view returns (uint256) {
        return IERC20(artistToken).balanceOf(address(this));
    }
}
