// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UnlockedSaleVault} from "./vaults/UnlockedSaleVault.sol";

/**
 * @title MostroBondingCurve
 * @notice Linear bonding curve for purchasing artist tokens from the UnlockedSaleVault.
 *         Price increases with each token sold. USDC proceeds are forwarded to the Diamond.
 */
contract MostroBondingCurve {

    using SafeERC20 for IERC20;

    // ==================== State Variables =====================

    address public immutable diamond;
    IERC20 public immutable artistToken;
    IERC20 public immutable usdc;
    UnlockedSaleVault public immutable saleVault;

    uint256 public tokensSold;
    bool public paused;

    uint256 public constant BASE_PRICE = 10_000;  // 0.01 USDC (6 decimals)
    uint256 public constant SLOPE      = 1_000;   // 0.001 USDC per token sold (6 decimals)

    // ==================== Events =====================

    event Buy(address indexed buyer, uint256 amount, uint256 cost);
    event PausedUpdated(bool paused);

    // ==================== Errors =====================

    error MustBeANonZeroAddress();
    error OnlyDiamond();
    error ContractIsPaused();
    error AmountIsZero();
    error InsufficientVaultBalance();
    error SlippageExceeded();

    // ==================== Modifiers =====================

    modifier whenNotPaused() {
        if (paused) revert ContractIsPaused();
        _;
    }

    modifier onlyDiamond() {
        if (msg.sender != diamond) revert OnlyDiamond();
        _;
    }

    // ==================== Constructor =====================

    /**
     * @param _diamond          Diamond proxy — receives USDC proceeds and controls pause.
     * @param _artistToken      ERC20 artist token sold through this curve.
     * @param _usdc             USDC token used as payment currency.
     * @param _saleVault        UnlockedSaleVault holding the tokens available for sale.
     */
    constructor(address _diamond, address _artistToken, address _usdc, address _saleVault) {
        if (_diamond == address(0) || _artistToken == address(0) ||
            _usdc == address(0) || _saleVault == address(0)) revert MustBeANonZeroAddress();
        diamond     = _diamond;
        artistToken = IERC20(_artistToken);
        usdc        = IERC20(_usdc);
        saleVault   = UnlockedSaleVault(_saleVault);
    }

    // ==================== Public Functions =====================

    /// @notice Returns the current price of the next token in USDC base units.
    function getCurrentPrice() public view returns (uint256) {
        return BASE_PRICE + SLOPE * tokensSold;
    }

    /**
     * @notice Returns the total USDC cost to buy `amount` tokens at current supply.
     * @dev    Computes the area under the linear curve between tokensSold and tokensSold + amount.
     */
    function calculateCost(uint256 amount) public view returns (uint256) {
        if (amount == 0) revert AmountIsZero();
        uint256 start = tokensSold;
        uint256 end   = start + amount;
        return BASE_PRICE * amount + (SLOPE * (end * (end - 1) - start * (start - 1))) / 2;
    }

    /// @notice Pauses or unpauses purchases. Callable only by the Diamond.
    function setPaused(bool _paused) external onlyDiamond {
        paused = _paused;
        emit PausedUpdated(_paused);
    }

    /**
     * @notice Purchase `amount` artist tokens by paying USDC.
     * @dev    Tokens are transferred from UnlockedSaleVault (which has pre-approved this contract).
     *         USDC proceeds are forwarded to the Diamond.
     * @param amount  Number of artist tokens to purchase.
     * @param maxCost Maximum USDC the caller is willing to pay (slippage protection).
     */
    function buy(uint256 amount, uint256 maxCost) external whenNotPaused {
        if (amount == 0) revert AmountIsZero();
        if (amount > saleVault.balance()) revert InsufficientVaultBalance();

        uint256 cost = calculateCost(amount);
        if (cost > maxCost) revert SlippageExceeded();

        tokensSold += amount;

        usdc.safeTransferFrom(msg.sender, address(saleVault), cost);
        artistToken.safeTransferFrom(address(saleVault), msg.sender, amount);

        emit Buy(msg.sender, amount, cost);
    }

}
