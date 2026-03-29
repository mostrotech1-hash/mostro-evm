// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @dev Solidity 0.8+ has built-in overflow checks on arithmetic. BPS splits use `Math.mulDiv`
///      in `VaultDeployer` / `VaultDeployerFacet` to avoid overflow on large `total * bps`.
abstract contract BaseVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable TOKEN;
    address public immutable MULTISIG;
    address public immutable CONTRACT;

    uint256 public totalReceived;
    uint256 public totalReleased;

    bool public depositInitialized;

    event AccountingIncreased(uint256 amount, uint256 totalReceived);
    event AssetReceived(
        address indexed from,
        uint256 amount,
        uint256 totalReceived
    );
    event AssetReleased(
        address indexed recipient,
        uint256 amount,
        uint256 totalReleased
    );

    error NotMultisig();
    error ZeroAmount();
    error ZeroAddress();
    error InsufficientBalance();
    error DepositAlreadyInitialized();
    error NotContract();

    /*
     * Initializes immutable vault dependencies:
     * - MULTISIG: authorized operator for release functions in child vaults.
     * - TOKEN: ERC20 token managed by this vault.
     * - CONTRACT: controller contract allowed to perform initial deposit.
     */
    constructor(address _multisig, address _token, address _contract) {
        if (_multisig == address(0)) revert ZeroAddress();
        if (_token == address(0)) revert ZeroAddress();
        if (_contract == address(0)) revert ZeroAddress();

        MULTISIG = _multisig;
        TOKEN = IERC20(_token);
        CONTRACT = _contract;
    }

    /*
     * Pulls TOKEN from `from` into this vault via transferFrom.
     * Token flow: `from` -> `address(this)`.
     * Can be executed only once due to `depositInitialized`.
     */
    function _deposit(address from, uint256 amount) internal nonReentrant {
        if (depositInitialized) revert DepositAlreadyInitialized();
        if (from == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (TOKEN.balanceOf(from) < amount) revert InsufficientBalance();

        TOKEN.safeTransferFrom(from, address(this), amount);

        totalReceived += amount;
        depositInitialized = true;

        emit AssetReceived(from, amount, totalReceived);
    }

    /*
     * Sends TOKEN from this vault to `recipient`.
     * Token flow: `address(this)` -> `recipient`.
     * Used by child contracts for controlled token releases.
     */
    function _release(address recipient, uint256 amount) internal nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (TOKEN.balanceOf(address(this)) < amount)
            revert InsufficientBalance();

        totalReleased += amount;

        TOKEN.safeTransfer(recipient, amount);

        emit AssetReleased(recipient, amount, totalReleased);
    }

    /*
     * Updates `totalReceived` accounting only.
     * No ERC20 transfer is performed in this function.
     */
    function receivedAmount(uint256 amount) internal {
        if (amount == 0) revert ZeroAmount();
        totalReceived += amount;

        emit AccountingIncreased(amount, totalReceived);
    }

    /*
     * Returns current TOKEN balance held by this vault.
     */
    function vaultBalance() external view returns (uint256) {
        return TOKEN.balanceOf(address(this));
    }

    /*
     * Access modifier for controller-only entry points.
     */
    modifier onlyContract() {
        _onlyContract();
        _;
    }

    /*
     * Access modifier for multisig-only entry points.
     */
    modifier onlyMultisig() {
        _onlyMultisig();
        _;
    }

    /*
     * Reverts unless caller is MULTISIG.
     */
    function _onlyMultisig() internal view {
        if (msg.sender != MULTISIG) revert NotMultisig();
    }

    /*
     * Reverts unless caller is CONTRACT.
     */
    function _onlyContract() internal view {
        if (msg.sender != CONTRACT) revert NotContract();
    }
}
