// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MostroRoleManager} from "../src/MostroRoleManager.sol"; 

contract MostroRoleManagerTest is Test {
    MostroRoleManager public roleManager;

    address superAdmin1 = address(0x1);
    address superAdmin2 = address(0x2);
    address admin = address(0x3);
    address user = address(0x4);

    function setUp() public {
        roleManager = new MostroRoleManager(superAdmin1);
    }

    // --- Role Lifecycle Tests ---

    function testConstructorInitialisesSuperAdmin() public {
        roleManager = new MostroRoleManager(superAdmin1);

        assertTrue(roleManager.isSuperAdmin(superAdmin1));
        assertEq(roleManager.superAdminCount(), 1);
    }

    function testConstructorRevertsOnZeroAddress() public {
        vm.expectRevert(MostroRoleManager.MustBeANonZeroAddress.selector);
        roleManager = new MostroRoleManager(address(0));
    }

    function testAddAdmin() public {
        vm.prank(superAdmin1);
        roleManager.addAdmin(admin);
        
        assertTrue(roleManager.isAdmin(admin));
        assertEq(roleManager.adminCount(), 1);
    }

    function testRevertsAddAdminIfCallerIsNotASuperAdmin() public {
        vm.prank(user);
        vm.expectRevert(MostroRoleManager.NotASuperAdmin.selector);
        roleManager.addAdmin(admin);
    }

    function testAddAdminRevertsOnZeroAddress() public {
        vm.prank(superAdmin1);
        vm.expectRevert(MostroRoleManager.MustBeANonZeroAddress.selector);
        roleManager.addAdmin(address(0));
    }

    function testAddAdminRevertsIfAlreadyAnAdmin() public {
        vm.startPrank(superAdmin1);
        roleManager.addAdmin(admin);

        vm.expectRevert(MostroRoleManager.AlreadyAnAdmin.selector);
        roleManager.addAdmin(admin);
        vm.stopPrank();
    }

    function testAdminRevertsIfAlreadyASuperAdmin() public {
        vm.prank(superAdmin1);
        vm.expectRevert(MostroRoleManager.AlreadyASuperAdmin.selector);
        roleManager.addAdmin(superAdmin1);
    }

   function testRemoveAdmin() public {
        vm.startPrank(superAdmin1);
        roleManager.addAdmin(admin);
        roleManager.removeAdmin(admin);
        vm.stopPrank();

        assertFalse(roleManager.isAdmin(admin));
        assertEq(roleManager.adminCount(), 0);
    }

    function testRemoveAdminFailsIfCallerIsNotASuperAdmin() public {
        vm.prank(superAdmin1);
        roleManager.addAdmin(admin);

        vm.prank(user);
        vm.expectRevert(MostroRoleManager.NotASuperAdmin.selector);
        roleManager.removeAdmin(admin);
    }


    function testAddSuperAdmin() public {
        vm.prank(superAdmin1);
        roleManager.addSuperAdmin(superAdmin2);
        
        assertTrue(roleManager.isSuperAdmin(superAdmin2));
        assertEq(roleManager.superAdminCount(), 2);
    }

    function testAddSuperAdminRevertsIfCallerIsNotASuperAdmin() public {
        vm.prank(user);
        vm.expectRevert(MostroRoleManager.NotASuperAdmin.selector);
        roleManager.addSuperAdmin(superAdmin2);
    }

     function testAddSuperAdminRevertsOnZeroAddress() public {
        vm.prank(superAdmin1);
        vm.expectRevert(MostroRoleManager.MustBeANonZeroAddress.selector);
        roleManager.addSuperAdmin(address(0));
    }

    function testAddSuperAdminRevertsIfAlreadyASuperAdmin() public {
        vm.prank(superAdmin1);
        vm.expectRevert(MostroRoleManager.AlreadyASuperAdmin.selector);
        roleManager.addSuperAdmin(superAdmin1);
    }

    function testAddSuperAdminRevertsIfAlreadyAnAdmin() public {
        vm.startPrank(superAdmin1);
        roleManager.addAdmin(admin);

        vm.expectRevert(MostroRoleManager.AlreadyAnAdmin.selector);
        roleManager.addSuperAdmin(admin);
        vm.stopPrank();
    }

    function testRemoveSuperAdmin() public {
        vm.startPrank(superAdmin1);
        roleManager.addSuperAdmin(superAdmin2);
        roleManager.removeSuperAdmin(superAdmin2);
        vm.stopPrank();

        assertFalse(roleManager.isSuperAdmin(superAdmin2));
        assertEq(roleManager.superAdminCount(), 1);
    }

    function testRemoveSuperAdminRevertsIfCallerIsNotASuperAdmin() public {
        vm.prank(superAdmin1);
        roleManager.addSuperAdmin(superAdmin2);

        vm.prank(user);
        vm.expectRevert(MostroRoleManager.NotASuperAdmin.selector);
        roleManager.removeSuperAdmin(superAdmin2);
    }

    function testRemoveSuperAdminRevertsIfNotASuperAdmin() public {
        vm.prank(superAdmin1);
        vm.expectRevert(MostroRoleManager.NotASuperAdmin.selector);
        roleManager.removeSuperAdmin(user);
    }

    // --- Critical Rule Tests ---

    function testRemoveSuperAdminRevertsOnLastSuperAdmin() public {
        vm.prank(superAdmin1);
        vm.expectRevert(MostroRoleManager.CannotRemoveLastSuperAdmin.selector);
        roleManager.removeSuperAdmin(superAdmin1);
    }

    function testRemoveSuperAdminSucceedsIfMultipleSuperAdminExists() public {
        // Add a second one first
        vm.prank(superAdmin1);
        roleManager.addSuperAdmin(superAdmin2);

        // Now remove the first one
        vm.prank(superAdmin2);
        roleManager.removeSuperAdmin(superAdmin1);
        
        assertFalse(roleManager.isSuperAdmin(superAdmin1));
        assertEq(roleManager.superAdminCount(), 1);
    }

    function testSelfRevokeAdmin() public {
        vm.prank(superAdmin1);
        roleManager.addAdmin(admin);

        vm.prank(admin);
        roleManager.selfRevoke();
        
        assertFalse(roleManager.isAdmin(admin));
    }

    function testSelfRevokeSuperAdmin() public {
        vm.prank(superAdmin1);
        roleManager.addSuperAdmin(superAdmin2);

        vm.prank(superAdmin2);
        roleManager.selfRevoke();

        assertFalse(roleManager.isSuperAdmin(superAdmin2));
        assertEq(roleManager.superAdminCount(), 1);
    }

    function testSelfRevokeRevertsIfLastSuperAdmin() public {
        vm.prank(superAdmin1);
        vm.expectRevert(MostroRoleManager.CannotRemoveLastSuperAdmin.selector);
        roleManager.selfRevoke();
    }

    function testIsAdminReturnsFalseAfterRemoval() public {
        vm.startPrank(superAdmin1);
        roleManager.addAdmin(admin);
        assertTrue(roleManager.isAdmin(admin));
        
        roleManager.removeAdmin(admin);
        vm.stopPrank();

        assertFalse(roleManager.isAdmin(admin));
    }

    function testIsAdminRevertsForNonAdmin() public view {
        assertFalse(roleManager.isAdmin(user));
    }

    function testIsSuperAdminReturnsFalseForNonSuperAdmin() public view {
        assertFalse(roleManager.isSuperAdmin(user));
    }

     function testIsSuperAdminReturnsTrueForSeededAdmin() public view {
        assertTrue(roleManager.isSuperAdmin(superAdmin1));
    }

    function testIsSuperAdminReturnsFalseAfterRemoval() public {
        vm.startPrank(superAdmin1);
        roleManager.addSuperAdmin(superAdmin2);
        assertTrue(roleManager.isSuperAdmin(superAdmin2));

        roleManager.removeSuperAdmin(superAdmin2);
        vm.stopPrank();

        assertFalse(roleManager.isSuperAdmin(superAdmin2));
    }

     /// @dev Initial state: 1 SuperAdmin (weight 2), 0 Admins → total = 2
    function testGetTotalVoteWeightInitialState() public view {
        assertEq(roleManager.getTotalVoteWeight(), 2);
    }

    function testGetTotalVoteWeightWithMultipleSuperAdminsAndAdmin() public {
        vm.startPrank(superAdmin1);
        roleManager.addAdmin(admin); // +1
        roleManager.addSuperAdmin(superAdmin2); // +2
        vm.stopPrank();

        // Initial(2) + Admin(1) + NewSuper(2) = 5
        assertEq(roleManager.getTotalVoteWeight(), 5);
    }
}