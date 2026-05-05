// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MostroArtistToken} from "./MostroArtistToken.sol";
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
    //UnlockedSaleVaultFacet public immutable saleVault;
    uint256 public tokensSold; // Total number of tokens solded through the bonding curve
    uint256 public constant BASE_PRICE = 0.01 ether; // Base price for the first token
    uint256 public constant SLOPE = 0.001 ether; // Price increase per token minted */

    // ==================== Events =====================

    event Buy(address indexed buyer, uint256 amount, uint256 cost);

    // ==================== Constructor =====================

    constructor(address _diamondContract) {
        DiamondContract = _diamondContract;
        artistToken = MostroArtistToken(_diamondContract);
        //saleVault = UnlockedSaleVaultFacet(_diamondContract);
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
    function buy(uint256 amount) external payable {
        
    }

}