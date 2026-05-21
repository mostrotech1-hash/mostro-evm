// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract BaseColdVault {

    // ─── State Variables ──────────────────────────────────

    address public immutable artistToken;
    address public immutable diamond;
    address public immutable releaseController;

    mapping(address => bool) public approvedDestinations;

    // ─── Events ───────────────────────────────────────────

    event DestinationApproved(address indexed destination);
    event DestinationRevoked(address indexed destination);
    event TokensReleased(address indexed destination, uint256 amount);

    // ─── Errors ───────────────────────────────────────────

    error MustBeANonZeroAddress();
    error OnlyReleaseController();
    error DestinationNotApproved();
    error DestinationAlreadyApproved();
    error DestinationNotRegistered();
    error TransferFailed();

    // ─── Modifier ─────────────────────────────────────────

    modifier onlyReleaseController() {
        if (msg.sender != releaseController) revert OnlyReleaseController();
        _;
    }

    // ─── Constructor ──────────────────────────────────────

    constructor(address _artistToken, address _diamond, address _releaseController) {
        if (_artistToken == address(0) || _diamond == address(0) || _releaseController == address(0))
            revert MustBeANonZeroAddress();
        artistToken = _artistToken;
        diamond = _diamond;
        releaseController = _releaseController;
    }

    // ─── Release Controller Functions ─────────────────────

    function approveDestination(address destination) external onlyReleaseController {
        if (destination == address(0)) revert MustBeANonZeroAddress();
        if (approvedDestinations[destination]) revert DestinationAlreadyApproved();
        approvedDestinations[destination] = true;
        emit DestinationApproved(destination);
    }

    function revokeDestination(address destination) external onlyReleaseController {
        if (!approvedDestinations[destination]) revert DestinationNotRegistered();
        approvedDestinations[destination] = false;
        emit DestinationRevoked(destination);
    }

    function release(address destination, uint256 amount) external onlyReleaseController {
        if (!approvedDestinations[destination]) revert DestinationNotApproved();
        if (!IERC20(artistToken).transfer(destination, amount)) revert TransferFailed();
        emit TokensReleased(destination, amount);
    }

    // ─── View Functions ───────────────────────────────────

    function balance() external view returns (uint256) {
        return IERC20(artistToken).balanceOf(address(this));
    }
}
