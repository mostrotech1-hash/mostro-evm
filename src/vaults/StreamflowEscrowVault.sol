// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StreamflowEscrowVault {

    // ─── State Variables ──────────────────────────────────

    address public immutable artistToken;
    address public immutable diamond;

    // ─── Errors ───────────────────────────────────────────

    error MustBeANonZeroAddress();

    // ─── Constructor ──────────────────────────────────────

    constructor(address _artistToken, address _diamond) {
        if (_artistToken == address(0) || _diamond == address(0)) revert MustBeANonZeroAddress();
        artistToken = _artistToken;
        diamond = _diamond;
    }

    // ─── View Functions ───────────────────────────────────

    function balance() external view returns (uint256) {
        return IERC20(artistToken).balanceOf(address(this));
    }
}
