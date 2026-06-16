// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {GenesisVault} from "src/vaults/GenesisVault.sol";
import {BaseColdVault} from "src/vaults/BaseColdVault.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock Artist Token", "MAT") {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

contract BaseColdVaultTest is Test {

    event DestinationApproved(address indexed destination);
    event TokensReleased(address indexed destination, uint256 amount);

    MockToken internal token;
    GenesisVault internal vault;

    address internal multisig = makeAddr("multisig");
    address internal hotVault = makeAddr("hotVault");
    address internal attacker = makeAddr("attacker");

    uint256 internal constant INITIAL_BALANCE = 300_000e18;

    function setUp() external {
        token = new MockToken();
        vault = new GenesisVault(address(token), multisig);
        token.mint(address(vault), INITIAL_BALANCE);
    }

    // ─── constructor ──────────────────────────────────────────────────────────

    function test_constructor_setsArtistToken() external view {
        assertEq(vault.artistToken(), address(token));
    }

    function test_constructor_setsReleaseController() external view {
        assertEq(vault.releaseController(), multisig);
    }

    function test_constructor_revertsOnZeroArtistToken() external {
        vm.expectRevert(BaseColdVault.MustBeANonZeroAddress.selector);
        new GenesisVault(address(0), multisig);
    }

    function test_constructor_revertsOnZeroReleaseController() external {
        vm.expectRevert(BaseColdVault.MustBeANonZeroAddress.selector);
        new GenesisVault(address(token), address(0));
    }

    // ─── approveDestination ───────────────────────────────────────────────────

    function test_approveDestination_setsMapping() external {
        vm.prank(multisig);
        vault.approveDestination(hotVault);
        assertTrue(vault.approvedDestinations(hotVault));
    }

    function test_approveDestination_emitsEvent() external {
        vm.prank(multisig);
        vm.expectEmit(true, false, false, false);
        emit DestinationApproved(hotVault);
        vault.approveDestination(hotVault);
    }

    function test_approveDestination_revertsIfNotController() external {
        vm.prank(attacker);
        vm.expectRevert(BaseColdVault.OnlyReleaseController.selector);
        vault.approveDestination(hotVault);
    }

    function test_approveDestination_revertsOnZeroAddress() external {
        vm.prank(multisig);
        vm.expectRevert(BaseColdVault.MustBeANonZeroAddress.selector);
        vault.approveDestination(address(0));
    }

    function test_approveDestination_revertsIfAlreadyApproved() external {
        vm.startPrank(multisig);
        vault.approveDestination(hotVault);
        vm.expectRevert(BaseColdVault.DestinationAlreadyApproved.selector);
        vault.approveDestination(hotVault);
        vm.stopPrank();
    }

    // ─── release ─────────────────────────────────────────────────────────────

    function test_release_transfersTokensToDestination() external {
        vm.startPrank(multisig);
        vault.approveDestination(hotVault);
        vault.release(hotVault, 100e18);
        vm.stopPrank();
        assertEq(token.balanceOf(hotVault), 100e18);
        assertEq(token.balanceOf(address(vault)), INITIAL_BALANCE - 100e18);
    }

    function test_release_emitsEvent() external {
        vm.startPrank(multisig);
        vault.approveDestination(hotVault);
        vm.expectEmit(true, false, false, true);
        emit TokensReleased(hotVault, 100e18);
        vault.release(hotVault, 100e18);
        vm.stopPrank();
    }

    function test_release_revertsOnZeroAmount() external {
        vm.startPrank(multisig);
        vault.approveDestination(hotVault);
        vm.expectRevert(BaseColdVault.InvalidAmount.selector);
        vault.release(hotVault, 0);
        vm.stopPrank();
    }

    function test_release_revertsIfNotController() external {
        vm.startPrank(multisig);
        vault.approveDestination(hotVault);
        vm.stopPrank();
        vm.prank(attacker);
        vm.expectRevert(BaseColdVault.OnlyReleaseController.selector);
        vault.release(hotVault, 100e18);
    }

    function test_release_revertsIfDestinationNotApproved() external {
        vm.prank(multisig);
        vm.expectRevert(BaseColdVault.DestinationNotApproved.selector);
        vault.release(hotVault, 100e18);
    }

    function test_release_fullBalance() external {
        vm.startPrank(multisig);
        vault.approveDestination(hotVault);
        vault.release(hotVault, INITIAL_BALANCE);
        vm.stopPrank();
        assertEq(token.balanceOf(address(vault)), 0);
        assertEq(token.balanceOf(hotVault), INITIAL_BALANCE);
    }

    function test_release_canReleaseInMultipleTransfers() external {
        address hotVault2 = makeAddr("hotVault2");
        vm.startPrank(multisig);
        vault.approveDestination(hotVault);
        vault.approveDestination(hotVault2);
        vault.release(hotVault, 100e18);
        vault.release(hotVault2, 200e18);
        vm.stopPrank();
        assertEq(token.balanceOf(hotVault), 100e18);
        assertEq(token.balanceOf(hotVault2), 200e18);
        assertEq(token.balanceOf(address(vault)), INITIAL_BALANCE - 300e18);
    }
}
