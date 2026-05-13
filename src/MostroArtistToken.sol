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
    error OnlyFactory();

    // ─── Constructor ──────────────────────────────────────

    constructor(address _factory) ERC20("", "") {
        if (_factory == address(0)) revert MustBeANonZeroAddress();
        factory = _factory;
    }

    // ─── Initializer ──────────────────────────────────────

    function initialize(
        string calldata _name,
        string calldata _symbol,
        uint256 _totalSupply,
        address _diamond
    ) external {
        if (msg.sender != factory) revert OnlyFactory();
        if (_initialized) revert AlreadyInitialized();
        if (_diamond == address(0)) revert MustBeANonZeroAddress();
        if (_totalSupply == 0) revert SupplyMustBeGreaterThanZero();

        _initialized = true;
        _tokenName = _name;
        _tokenSymbol = _symbol;
        factory = _diamond;

        _mint(_diamond, _totalSupply);
    }

    function name() public view override returns (string memory) {
        return _tokenName;
    }

    function symbol() public view override returns (string memory) {
        return _tokenSymbol;
    }
}