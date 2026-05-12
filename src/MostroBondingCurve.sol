// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MostroArtistToken} from "./MostroArtistToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/* import {UnlockedSaleVaultFacet} from "./facets/UnlockedSaleVaultFacet.sol";*/

/**
 * @title MostroBondingCurve
 * @dev This bonding curve will be connected to UnlockedSaleVault.
 * @dev The price of the token increases as more tokens are minted, following a linear bonding curve.
 */

contract MostroBondingCurve {

    // ==================== State Variables =====================

    address public immutable DiamondContract;
    MostroArtistToken public immutable artistToken;
    IERC20 public immutable usdc;
    address public immutable saleVault; // UnlockedSaleVaultFacet lives at DiamondContract
    uint256 public tokensSold; // Total number of tokens solded through the bonding curve
    uint256 public constant BASE_PRICE = 0.01 ether; // Base price for the first token
    uint256 public constant SLOPE = 0.001 ether; // Price increase per token minted */

    // ==================== Events =====================

    event Buy(address indexed buyer, uint256 amount, uint256 cost);

    // ==================== Constructor =====================

    constructor(address _diamondContract, address _artistToken, address _usdc) {
        require(_diamondContract != address(0), "Invalid diamond");
        require(_artistToken != address(0), "Invalid token");
        require(_usdc != address(0), "Invalid USDC");
        DiamondContract = _diamondContract;
        artistToken = MostroArtistToken(_artistToken);
        usdc = IERC20(_usdc);
        saleVault = _diamondContract;
    }

    // ==================== Public Functions =====================

    function getCurrentPrice() public view returns (uint256) {
        return BASE_PRICE + SLOPE * tokensSold;
    }

    function calculateCost(uint256 amount) public view returns (uint256) {
        require(amount > 0, "Amount is zero");

        uint256 start = tokensSold;
        uint256 end = start + amount;

        return
            BASE_PRICE * amount +
            (SLOPE * (end * (end - 1) - start * (start - 1))) / 2;
    }

    /**
     * @dev Allows users to purchase tokens from the bonding curve.
     * @param amount The number of tokens to purchase.
     */
    function buy(uint256 amount) external {
        require(amount <= artistToken.balanceOf(saleVault), "Not enough tokens available");
        uint256 cost = calculateCost(amount);

        // Pull USDC from buyer to the vault
        bool usdcSent = usdc.transferFrom(msg.sender, saleVault, cost);
        require(usdcSent, "USDC transfer failed");

        tokensSold += amount;

        // Push artist tokens from vault to buyer
        bool tokenSent = artistToken.transferFrom(saleVault, msg.sender, amount);
        require(tokenSent, "Artist token transfer failed");

        emit Buy(msg.sender, amount, cost);
    }

}
