// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Governance} from "../src/Governance.sol"; 

contract GovernanceFacetTest is Test {
    Governance public gov;

    address superAdmin1 = address(0x1);
    address superAdmin2 = address(0x2);
    address admin = address(0x3);
    address user = address(0x4);

    function setUp() public {
        gov = new Governance();
        
        // Since the contract has no constructor, we manually set the first SuperAdmin
        _seedSuperAdmin(superAdmin1);
    }

    /// @dev Writes firstSuperAdmin = true and superAdminCount = 1 into storage.
    function _seedSuperAdmin(address _account) internal {
        bytes32 superAdminSlot = keccak256(abi.encode(_account, uint256(1)));
        vm.store(address(gov), superAdminSlot, bytes32(uint256(1)));
        vm.store(address(gov), bytes32(uint256(3)), bytes32(uint256(1)));
    }

    // --- Role Lifecycle Tests ---

    function testAddAdmin() public {
        vm.prank(superAdmin1);
        gov.addAdmin(admin);
        
        assertTrue(gov.isAdmin(admin));
        assertEq(gov.adminCount(), 1);
    }

    function testRevertsAddAdminIfCallerIsNotASuperAdmin() public {
        vm.prank(user);
        vm.expectRevert(Governance.NotASuperAdmin.selector);
        gov.addAdmin(admin);
    }

    function testAddAdminRevertsOnZeroAddress() public {
        vm.prank(superAdmin1);
        vm.expectRevert(Governance.MustBeANonZeroAddress.selector);
        gov.addAdmin(address(0));
    }

    function testAddAdminRevertsIfAlreadyAnAdmin() public {
        vm.startPrank(superAdmin1);
        gov.addAdmin(admin);

        vm.expectRevert(Governance.AlreadyAnAdmin.selector);
        gov.addAdmin(admin);
        vm.stopPrank();
    }

    function testAdminRevertsIfAlreadyASuperAdmin() public {
        vm.prank(superAdmin1);
        vm.expectRevert(Governance.AlreadyASuperAdmin.selector);
        gov.addAdmin(superAdmin1);
    }

   function testRemoveAdmin() public {
        vm.startPrank(superAdmin1);
        gov.addAdmin(admin);
        gov.removeAdmin(admin);
        vm.stopPrank();

        assertFalse(gov.isAdmin(admin));
        assertEq(gov.adminCount(), 0);
    }

    function testRemoveAdminFailsIfCallerIsNotASuperAdmin() public {
        vm.prank(superAdmin1);
        gov.addAdmin(admin);

        vm.prank(user);
        vm.expectRevert(Governance.NotASuperAdmin.selector);
        gov.removeAdmin(admin);
    }


    function testAddSuperAdmin() public {
        vm.prank(superAdmin1);
        gov.addSuperAdmin(superAdmin2);
        
        assertTrue(gov.isSuperAdmin(superAdmin2));
        assertEq(gov.superAdminCount(), 2);
    }

    function testAddSuperAdminRevertsIfCallerIsNotASuperAdmin() public {
        vm.prank(user);
        vm.expectRevert(Governance.NotASuperAdmin.selector);
        gov.addSuperAdmin(superAdmin2);
    }

     function testAddSuperAdminRevertsOnZeroAddress() public {
        vm.prank(superAdmin1);
        vm.expectRevert(Governance.MustBeANonZeroAddress.selector);
        gov.addSuperAdmin(address(0));
    }

    function testAddSuperAdminRevertsIfAlreadyASuperAdmin() public {
        vm.prank(superAdmin1);
        vm.expectRevert(Governance.AlreadyASuperAdmin.selector);
        gov.addSuperAdmin(superAdmin1);
    }

    function testAddSuperAdminRevertsIfAlreadyAnAdmin() public {
        vm.startPrank(superAdmin1);
        gov.addAdmin(admin);

        vm.expectRevert(Governance.AlreadyAnAdmin.selector);
        gov.addSuperAdmin(admin);
        vm.stopPrank();
    }

    function testRemoveSuperAdmin() public {
        vm.startPrank(superAdmin1);
        gov.addSuperAdmin(superAdmin2);
        gov.removeSuperAdmin(superAdmin2);
        vm.stopPrank();

        assertFalse(gov.isSuperAdmin(superAdmin2));
        assertEq(gov.superAdminCount(), 1);
    }

    function testRemoveSuperAdminRevertsIfCallerIsNotASuperAdmin() public {
        vm.prank(superAdmin1);
        gov.addSuperAdmin(superAdmin2);

        vm.prank(user);
        vm.expectRevert(Governance.NotASuperAdmin.selector);
        gov.removeSuperAdmin(superAdmin2);
    }

    function testRemoveSuperAdminRevertsIfNotASuperAdmin() public {
        vm.prank(superAdmin1);
        vm.expectRevert(Governance.NotASuperAdmin.selector);
        gov.removeSuperAdmin(user);
    }

    // --- Critical Rule Tests ---

    function testRemoveSuperAdminRevertsOnLastSuperAdmin() public {
        vm.prank(superAdmin1);
        vm.expectRevert(Governance.CannotRemoveLastSuperAdmin.selector);
        gov.removeSuperAdmin(superAdmin1);
    }

    function testRemoveSuperAdminSucceedsIfMultipleSuperAdminExists() public {
        // Add a second one first
        vm.prank(superAdmin1);
        gov.addSuperAdmin(superAdmin2);

        // Now remove the first one
        vm.prank(superAdmin2);
        gov.removeSuperAdmin(superAdmin1);
        
        assertFalse(gov.isSuperAdmin(superAdmin1));
        assertEq(gov.superAdminCount(), 1);
    }

    function testSelfRevokeAdmin() public {
        vm.prank(superAdmin1);
        gov.addAdmin(admin);

        vm.prank(admin);
        gov.selfRevoke();
        
        assertFalse(gov.isAdmin(admin));
    }

    function testSelfRevokeSuperAdmin() public {
        vm.prank(superAdmin1);
        gov.addSuperAdmin(superAdmin2);

        vm.prank(superAdmin2);
        gov.selfRevoke();

        assertFalse(gov.isSuperAdmin(superAdmin2));
        assertEq(gov.superAdminCount(), 1);
    }

    function testSelfRevokeRevertsIfLastSuperAdmin() public {
        vm.prank(superAdmin1);
        vm.expectRevert(Governance.CannotRemoveLastSuperAdmin.selector);
        gov.selfRevoke();
    }

    function testIsAdminReturnsFalseAfterRemoval() public {
        vm.startPrank(superAdmin1);
        gov.addAdmin(admin);
        assertTrue(gov.isAdmin(admin));
        
        gov.removeAdmin(admin);
        vm.stopPrank();

        assertFalse(gov.isAdmin(admin));
    }

    function testIsAdminRevertsForNonAdmin() public view {
        assertFalse(gov.isAdmin(user));
    }

    function testIsSuperAdminReturnsFalseForNonSuperAdmin() public view {
        assertFalse(gov.isSuperAdmin(user));
    }

     function testIsSuperAdminReturnsTrueForSeededAdmin() public view {
        assertTrue(gov.isSuperAdmin(superAdmin1));
    }

    function testIsSuperAdminReturnsFalseAfterRemoval() public {
        vm.startPrank(superAdmin1);
        gov.addSuperAdmin(superAdmin2);
        assertTrue(gov.isSuperAdmin(superAdmin2));

        gov.removeSuperAdmin(superAdmin2);
        vm.stopPrank();

        assertFalse(gov.isSuperAdmin(superAdmin2));
    }

     /// @dev Initial state: 1 SuperAdmin (weight 2), 0 Admins → total = 2
    function testGetTotalVoteWeightInitialState() public view {
        assertEq(gov.getTotalVoteWeight(), 2);
    }

    function testGetTotalVoteWeightWithMultipleSuperAdminsAndAdmin() public {
        vm.startPrank(superAdmin1);
        gov.addAdmin(admin); // +1
        gov.addSuperAdmin(superAdmin2); // +2
        vm.stopPrank();

        // Initial(2) + Admin(1) + NewSuper(2) = 5
        assertEq(gov.getTotalVoteWeight(), 5);
    }
}