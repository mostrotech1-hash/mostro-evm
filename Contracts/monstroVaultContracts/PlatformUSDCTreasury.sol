// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title  PlatformUSDCTreasury
/// @notice Receives USDC from token sales and routes it out
///         on multisig instruction.
contract PlatformUSDCTreasury {
    string public constant VAULT_NAME = "PlatformUSDCTreasury";

    using SafeERC20 for IERC20;

    IERC20 public immutable usdc;
    address public immutable MULTISIG;
    address public immutable platformContract;

    uint256 public totalReceived;
    uint256 public totalWithdrawn;

    error NotMultisig();
    error ZeroAddress();
    error NotContract();
    error InvalidAmount();
    error InsufficientBalance();

    /// EVENTS
    event USDCReceived(
        address indexed from,
        uint256 amount,
        uint256 newBalance
    );

    event USDCWithdrawn(address indexed to, uint256 amount, uint256 newBalance);

    constructor(address _multisig, address _usdc, address _contract) {
        if (_multisig == address(0)) revert ZeroAddress();
        if (_usdc == address(0)) revert ZeroAddress();
        if (_contract == address(0)) revert ZeroAddress();

        MULTISIG = _multisig;
        usdc = IERC20(_usdc);
        platformContract = _contract;
    }

    /// @notice Deposit USDC into the treasury.
    function receiveUSDC(uint256 amount) external onlyContract {
        if (amount == 0) revert InvalidAmount();

        usdc.safeTransferFrom(msg.sender, address(this), amount);

        totalReceived += amount;

        emit USDCReceived(msg.sender, amount, usdc.balanceOf(address(this)));
    }

    /// @notice Multisig routes USDC out to a destination
    function withdraw(
        address plateFormWallet,
        uint256 amount
    ) external onlyMultisig {
        if (plateFormWallet == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();

        uint256 balance = usdc.balanceOf(address(this));
        if (amount > balance) revert InsufficientBalance();

        usdc.safeTransfer(plateFormWallet, amount);

        totalWithdrawn += amount;

        emit USDCWithdrawn(
            plateFormWallet,
            amount,
            usdc.balanceOf(address(this))
        );
    }

    function vaultBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
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
        if (msg.sender != platformContract) revert NotContract();
    }
}
