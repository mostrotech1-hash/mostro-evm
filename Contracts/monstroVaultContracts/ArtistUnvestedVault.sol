// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title  ArtistUnvestedVault
/// @notice Receives vested tokens from StreamFlowEscrowVault on schedule.
///         Tokens can ONLY exit through the approved Artist Drop Curve.
///         Artist cannot withdraw freely.
contract ArtistUnvestedVault {
    string public constant VAULT_NAME = "ArtistUnvestedVault";

    address public immutable artist;
    using SafeERC20 for IERC20;

    IERC20 public immutable TOKEN;
    address public immutable platformContract;
    address public immutable FromStreamFlowContract;

    uint256 public totalReceived;
    uint256 public totalRelease;

    error NotMultisig();
    error ZeroAddress();
    error NotContract();
    error InvalidAmount();
    error InsufficientBalance();

    /// EVENTS
    event TOKENReceived(
        address indexed from,
        uint256 amount,
        uint256 newBalance
    );

    constructor(address _token, address _artist, address _contract) {
        if (_contract == address(0)) revert ZeroAddress();
        if (_token == address(0)) revert ZeroAddress();
        if (_artist == address(0)) revert ZeroAddress();

        artist = _artist;
        TOKEN = IERC20(_token);
        FromStreamFlowContract = _contract;
    }

    /// @notice StreamFlowEscrowVault calls this after pushing tokens here.
    function receiveFromStreamFlow(uint256 amount) external onlyContract {
        if (amount == 0) revert InvalidAmount();

        TOKEN.safeTransferFrom(msg.sender, address(this), amount);

        totalReceived += amount;

        emit TOKENReceived(msg.sender, amount, TOKEN.balanceOf(address(this)));
    }

    modifier onlyContract() {
        _onlyContract();
        _;
    }

    function _onlyContract() internal view {
        if (msg.sender != FromStreamFlowContract) revert NotContract();
    }
}
