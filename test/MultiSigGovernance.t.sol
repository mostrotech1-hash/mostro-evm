// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MultisigGovernance} from "src/MultiSigGovernance.sol";

contract MockMostroRoleManager {

    mapping(address => bool) internal admins;
    mapping(address => bool) internal superAdmins;

    function setAdmin(address account) external {
        admins[account] = true;
    }

    function setSuperAdmin(address account) external {
        superAdmins[account] = true;
    }

    function isAdmin(address account) external view returns (bool) {
        return admins[account];
    }

    function isSuperAdmin(address account) external view returns (bool) {
        return superAdmins[account];
    }
}

contract MockTarget {
    uint256 public value;

    function setValue(uint256 newValue) external {
        value = newValue;
    }
}

contract MultiSigGovernanceTest is Test {

    MultisigGovernance internal governance;
    MockMostroRoleManager internal roleManager;
    MockTarget internal target;

    address internal admin = address(0xA11);
    address internal superAdmin = address(0xB22);
    address internal notAdminOrSuperAdmin = address(0xC33);

    function setUp() external {
        roleManager = new MockMostroRoleManager();
        target = new MockTarget();
        governance = new MultisigGovernance(address(roleManager));

        roleManager.setAdmin(admin);
        roleManager.setSuperAdmin(superAdmin);
    }

    function testSubmitProposal() external {
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 42);

        governance.submitProposal(address(target), data, 2);

        (uint256 id, address proposalTarget, bytes memory proposalData, uint256 threshold, uint256 weight, bool executed) =
            governance.getProposal(1);

        assertEq(id, 1);
        assertEq(proposalTarget, address(target));
        assertEq(proposalData, data);
        assertEq(threshold, 2);
        assertEq(weight, 0);
        assertEq(executed, false);
    }

    function testRevertApproveWhenNotAdminOrSuperAdmin() external {
        governance.submitProposal(address(target), abi.encodeWithSelector(MockTarget.setValue.selector, 1), 1);

        vm.prank(notAdminOrSuperAdmin);
        vm.expectRevert("The msg sender must have the admin or the super admin role");
        governance.approveProposal(1);
    }

    function testApproveProposalAsAdminAddsWeightOne() external {
        governance.submitProposal(address(target), abi.encodeWithSelector(MockTarget.setValue.selector, 1), 1);

        vm.prank(admin);
        governance.approveProposal(1);

        (, , , , uint256 weight, ) = governance.getProposal(1);
        assertEq(weight, 1);
        assertTrue(governance.hasApproved(1, admin));
    }

    function testApproveProposalAsSuperAdminAddsWeightTwo() external {
        governance.submitProposal(address(target), abi.encodeWithSelector(MockTarget.setValue.selector, 1), 2);

        vm.prank(superAdmin);
        governance.approveProposal(1);

        (, , , , uint256 weight, ) = governance.getProposal(1);
        assertEq(weight, 2);
        assertTrue(governance.hasApproved(1, superAdmin));
    }

    function testRevertExecuteProposalWhenThresholdNotReached() external {
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 77);
        governance.submitProposal(address(target), data, 4);

        vm.prank(admin);
        governance.approveProposal(1);

        vm.prank(superAdmin);
        governance.approveProposal(1);

        vm.expectRevert("Insufficient approval weight to execute this proposal");
        governance.executeProposal(1);
    }

    function testExecuteProposalAfterThresholdReached() external {
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 77);
        governance.submitProposal(address(target), data, 3);

        vm.prank(admin);
        governance.approveProposal(1);

        vm.prank(superAdmin);
        governance.approveProposal(1);

        governance.executeProposal(1);

        assertEq(target.value(), 77);
        (, , , , , bool executed) = governance.getProposal(1);
        assertTrue(executed);
    }
}
