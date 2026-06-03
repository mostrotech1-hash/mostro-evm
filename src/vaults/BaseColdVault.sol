// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract BaseColdVault {

    // ─── State Variables ──────────────────────────────────

    address public immutable artistToken;
    address public immutable releaseController;

    mapping(address => bool) public approvedDestinations;

    // ─── Events ───────────────────────────────────────────

    event DestinationApproved(address indexed destination);
    event TokensReleased(address indexed destination, uint256 amount);

    // ─── Errors ───────────────────────────────────────────

    error MustBeANonZeroAddress();
    error OnlyReleaseController();
    error DestinationNotApproved();
    error DestinationAlreadyApproved();
    error TransferFailed();

    // ─── Modifier ─────────────────────────────────────────

    modifier onlyReleaseController() {
        if (msg.sender != releaseController) revert OnlyReleaseController();
        _;
    }

    // ─── Constructor ──────────────────────────────────────

    constructor(address _artistToken, address _releaseController) {
        if (_artistToken == address(0) || _releaseController == address(0))
            revert MustBeANonZeroAddress();
        artistToken = _artistToken;
        releaseController = _releaseController;
    }

    // ─── Release Controller Functions ─────────────────────

    function approveDestination(address destination) external onlyReleaseController {
        if (destination == address(0)) revert MustBeANonZeroAddress();
        if (approvedDestinations[destination]) revert DestinationAlreadyApproved();
        approvedDestinations[destination] = true;
        emit DestinationApproved(destination);
    }

    function release(address destination, uint256 amount) external onlyReleaseController {
        if (!approvedDestinations[destination]) revert DestinationNotApproved();
        if (!IERC20(artistToken).transfer(destination, amount)) revert TransferFailed();
        emit TokensReleased(destination, amount);
    }
}
