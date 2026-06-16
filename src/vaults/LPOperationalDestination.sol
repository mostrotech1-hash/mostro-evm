// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title LPOperationalDestination
 * @dev Hot vault that receives tokens from LPVault.
 *      Holds tokens pending deployment to a DEX liquidity pool.
 */
contract LPOperationalDestination {

    // ─── State Variables ──────────────────────────────────

    address public immutable artistToken;
    address public immutable diamond;
    address public liquidityRouter;

    // ─── Events ───────────────────────────────────────────

    event LiquidityRouterSet(address indexed liquidityRouter);

    // ─── Errors ───────────────────────────────────────────

    error MustBeANonZeroAddress();
    error OnlyDiamond();
    error LiquidityRouterAlreadySet();

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

    function setLiquidityRouter(address _liquidityRouter) external onlyDiamond {
        if (_liquidityRouter == address(0)) revert MustBeANonZeroAddress();
        if (liquidityRouter != address(0)) revert LiquidityRouterAlreadySet();
        liquidityRouter = _liquidityRouter;
        IERC20(artistToken).approve(_liquidityRouter, type(uint256).max);
        emit LiquidityRouterSet(_liquidityRouter);
    }

    // ─── View Functions ───────────────────────────────────

    function balance() external view returns (uint256) {
        return IERC20(artistToken).balanceOf(address(this));
    }
}
