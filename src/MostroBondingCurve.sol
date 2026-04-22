// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MostroArtistToken} from "./MostroArtistToken.sol";

/**
 * @title MostroBondingCurve
 * @dev This bonding curve will be connected to 2 vaults: PublicPoolVault and UnlockedSaleVault.
 * @dev The price of the token increases as more tokens are minted, following a linear bonding curve.
 */

contract MostroBondingCurve {

    // ==================== State Variables =====================

    MostroArtistToken public immutable artistToken;
    uint256 public totalSupply;
    /* uint256 public constant BASE_PRICE = 0.01 ether; // Base price for the first token
    uint256 public constant PRICE_INCREMENT = 0.001 ether; // Price increase per token minted */

    // ==================== Events =====================

    event Buy(address indexed buyer, uint256 amount, uint256 cost);
    event Sell(address indexed seller, uint256 amount, uint256 cost);

    // ==================== Constructor =====================

    constructor(MostroArtistToken _artistToken) {
        artistToken = _artistToken;
    }

    // ==================== Public Functions =====================


    function k() public view returns (uint256) {
    }

    function spot() public view returns (uint256) {
    }

    /**
     * @dev Allows users to purchase tokens from the bonding curve.
     * @param amount The number of tokens to purchase.
     */
    function buy(uint256 amount) external payable {
        
    }

    /**
     * @dev Allows users to sell their tokens and receive a refund based on the bonding curve.
     * @param amount The number of tokens to sell.
     */
    function sell(uint256 amount) external {
        
    }
}