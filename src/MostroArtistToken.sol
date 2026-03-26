// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MostroArtistToken is ERC20 {

    // ─── State Variables ──────────────────────────────────

    address public factory;
    bool private _initialized;
    string private _tokenName;
    string private _tokenSymbol;

    // ─── Errors ───────────────────────────────────────────

    error AlreadyInitialized();
    error MustBeANonZeroAddress();
    error SupplyMustBeGreaterThanZero();

    // ─── Constructor ──────────────────────────────────────

    constructor(string memory _name,
        string memory _symbol,
        uint256 _totalSupply,
        address _diamond) ERC20(_name, _symbol) {
            if (_diamond == address(0)) revert MustBeANonZeroAddress();
            if (_totalSupply == 0) revert SupplyMustBeGreaterThanZero();

            factory = _diamond;
            _mint(_diamond, _totalSupply);
    }

    // ─── Functions ──────────────────────────────────────

    function name() public view override returns (string memory) {
        return _tokenName;
    }

    function symbol() public view override returns (string memory) {
        return _tokenSymbol;
    }
}