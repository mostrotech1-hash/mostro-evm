// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title UnlockedSaleVault
 * @dev Hot vault that receives tokens from PublicPoolVault and approves the bonding curve to spend them.
 */
contract UnlockedSaleVault {

    // ─── State Variables ──────────────────────────────────

    address public immutable artistToken;
    address public immutable diamond;
    address public bondingCurve;

    // ─── Events ───────────────────────────────────────────

    event BondingCurveSet(address indexed bondingCurve);

    // ─── Errors ───────────────────────────────────────────

    error MustBeANonZeroAddress();
    error OnlyDiamond();
    error BondingCurveAlreadySet();

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

    function setBondingCurve(address _bondingCurve) external onlyDiamond {
        if (_bondingCurve == address(0)) revert MustBeANonZeroAddress();
        if (bondingCurve != address(0)) revert BondingCurveAlreadySet();
        bondingCurve = _bondingCurve;
        IERC20(artistToken).approve(_bondingCurve, type(uint256).max);
        emit BondingCurveSet(_bondingCurve);
    }

    // ─── View Functions ───────────────────────────────────

    function balance() external view returns (uint256) {
        return IERC20(artistToken).balanceOf(address(this));
    }
}
