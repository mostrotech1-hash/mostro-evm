// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title BaseColdVault
 * @notice Immutable cold storage for artist tokens. Tokens are locked until the release
 *         controller explicitly whitelists a destination and authorizes a transfer.
 * @dev Abstract contract inherited by all four Mostro cold vaults. Access control is
 *      enforced exclusively through `releaseController` (multisig), ensuring no single
 *      admin key can unilaterally move funds.
 *
 *      Release flow:
 *        1. {MostroFactoryFacet} deploys the vault via `initializeColdVaults`.
 *        2. Multisig calls {approveDestination} to whitelist the target hot vault.
 *        3. Multisig calls {release} to transfer tokens to the approved destination.
 */
abstract contract BaseColdVault {

    // ─── State Variables ──────────────────────────────────

    /// @notice ERC20 artist token held in escrow by this vault.
    address public immutable artistToken;

    /// @notice Sole authority over destination approvals and token releases. Immutable after deployment.
    address public immutable releaseController;

    /// @notice Mapping of addresses authorized to receive releases. Managed exclusively by the release controller.
    mapping(address => bool) public approvedDestinations;

    // ─── Events ───────────────────────────────────────────

    /**
     * @notice Emitted when the release controller whitelists a new destination.
     * @param destination The address that was approved.
     */
    event DestinationApproved(address indexed destination);

    /**
     * @notice Emitted when tokens are successfully transferred to an approved destination.
     * @param destination The recipient address.
     * @param amount      The amount of `artistToken` transferred, in base units.
     */
    event TokensReleased(address indexed destination, uint256 amount);

    // ─── Errors ───────────────────────────────────────────

    /// @notice Thrown when a zero address is passed where a non-zero address is required.
    error MustBeANonZeroAddress();

    /// @notice Thrown when the caller is not the release controller.
    error OnlyReleaseController();

    /// @notice Thrown when attempting to release to an address not in `approvedDestinations`.
    error DestinationNotApproved();

    /// @notice Thrown when attempting to approve an address already present in `approvedDestinations`.
    error DestinationAlreadyApproved();

    /// @notice Thrown when the underlying ERC20 `transfer` call returns false.
    error TransferFailed();

    /// @notice Thrown when a zero amount is passed to {release}.
    error InvalidAmount();

    // ─── Modifier ─────────────────────────────────────────

    /// @dev Reverts with {OnlyReleaseController} if `msg.sender` is not the release controller.
    modifier onlyReleaseController() {
        if (msg.sender != releaseController) revert OnlyReleaseController();
        _;
    }

    // ─── Constructor ──────────────────────────────────────

    /**
     * @dev Sets immutable state. Both parameters are validated as non-zero to prevent
     *      deploying an inoperable vault.
     * @param _artistToken       ERC20 token this vault will hold.
     * @param _releaseController Multisig address with sole authority over releases.
     */
    constructor(address _artistToken, address _releaseController) {
        if (_artistToken == address(0) || _releaseController == address(0))
            revert MustBeANonZeroAddress();
        artistToken = _artistToken;
        releaseController = _releaseController;
    }

    // ─── Release Controller Functions ─────────────────────

    /**
     * @notice Adds `destination` to the set of addresses permitted to receive token releases.
     * @dev Reverts if `destination` is already approved to prevent duplicate multisig transactions
     *      from going unnoticed. Emits {DestinationApproved}.
     * @param destination Address to whitelist. Must be non-zero and not already approved.
     */
    function approveDestination(address destination) external onlyReleaseController {
        if (destination == address(0)) revert MustBeANonZeroAddress();
        if (approvedDestinations[destination]) revert DestinationAlreadyApproved();
        approvedDestinations[destination] = true;
        emit DestinationApproved(destination);
    }

    /**
     * @notice Transfers `amount` of `artistToken` to `destination`.
     * @dev `destination` must have been previously approved via {approveDestination}.
     *      Reverts with {TransferFailed} if the ERC20 transfer returns false.
     *      Emits {TokensReleased}.
     * @param destination Approved recipient address.
     * @param amount      Amount to transfer, in base units of `artistToken`.
     */
    function release(address destination, uint256 amount) external onlyReleaseController {
        if (amount == 0) revert InvalidAmount();
        if (!approvedDestinations[destination]) revert DestinationNotApproved();
        if (!IERC20(artistToken).transfer(destination, amount)) revert TransferFailed();
        emit TokensReleased(destination, amount);
    }
}
