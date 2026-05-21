// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title PlatformTreasury
 * @dev Hot vault that receives tokens from GenesisVault.
 *      Holds platform revenue tokens controlled by the Diamond.
 */
contract PlatformTreasury {

    // ─── State Variables ──────────────────────────────────

    address public immutable diamond;

    // ─── Events ───────────────────────────────────────────

    event TokensWithdrawn(address indexed token, address indexed to, uint256 amount);

    // ─── Errors ───────────────────────────────────────────

    error MustBeANonZeroAddress();
    error OnlyDiamond();
    error TransferFailed();

    // ─── Modifier ─────────────────────────────────────────

    modifier onlyDiamond() {
        if (msg.sender != diamond) revert OnlyDiamond();
        _;
    }

    // ─── Constructor ──────────────────────────────────────

    constructor(address _diamond) {
        if (_diamond == address(0)) revert MustBeANonZeroAddress();
        diamond = _diamond;
    }

    // ─── Diamond Functions ────────────────────────────────

    function withdraw(address token, address to, uint256 amount) external onlyDiamond {
        if (token == address(0) || to == address(0)) revert MustBeANonZeroAddress();
        if (!IERC20(token).transfer(to, amount)) revert TransferFailed();
        emit TokensWithdrawn(token, to, amount);
    }

    // ─── View Functions ───────────────────────────────────

    function balance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
