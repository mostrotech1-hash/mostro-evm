// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
abstract contract BaseVault {
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

    constructor(address _multisig, address _token, address _contract) {
        if (_multisig == address(0)) revert ZeroAddress();
        if (_token == address(0)) revert ZeroAddress();
        if (_contract == address(0)) revert ZeroAddress();

        MULTISIG = _multisig;
        TOKEN = IERC20(_token);
        CONTRACT = _contract;
    }

    /// @dev Can only be called once to initialize vault funding
    function _deposit(address from, uint256 amount) internal {
        if (depositInitialized) revert DepositAlreadyInitialized();
        if (from == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (TOKEN.balanceOf(from) < amount) revert InsufficientBalance();

        TOKEN.safeTransferFrom(from, address(this), amount);

        totalReceived += amount;
        depositInitialized = true;

        emit AssetReceived(from, amount, totalReceived);
    }

    /// @dev Send tokens out of vault
    function _release(address recipient, uint256 amount) internal {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (TOKEN.balanceOf(address(this)) < amount)
            revert InsufficientBalance();

        totalReleased += amount;

        TOKEN.safeTransfer(recipient, amount);

        emit AssetReleased(recipient, amount, totalReleased);
    }

    /// @dev Only updates accounting (no token transfer)
    function receivedAmount(uint256 amount) internal {
        if (amount == 0) revert ZeroAmount();
        totalReceived += amount;

        emit AccountingIncreased(amount, totalReceived);
    }

    function vaultBalance() external view returns (uint256) {
        return TOKEN.balanceOf(address(this));
    }

    modifier onlyContract() {
        _onlyContract();
        _;
    }

    modifier onlyMultisig() {
        _onlyMultisig();
        _;
    }

    function _onlyMultisig() internal view {
        if (msg.sender != MULTISIG) revert NotMultisig();
    }

    function _onlyContract() internal view {
        if (msg.sender != CONTRACT) revert NotContract();
    }
}
