// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MultisigGovernance} from "src/MultiSigGovernance.sol";

contract MockRoleManager {
    mapping(address => bool) internal admins;
    mapping(address => bool) internal superAdmins;

    function setAdmin(address account, bool value) external {
        admins[account] = value;
    }

    function setSuperAdmin(address account, bool value) external {
        superAdmins[account] = value;
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
    MockRoleManager internal roleManager;
    MockTarget internal target;

    address internal admin = address(0xA11);
    address internal superAdmin = address(0xB22);
    address internal outsider = address(0xC33);

    function setUp() external {
        roleManager = new MockRoleManager();
        target = new MockTarget();
        governance = new MultisigGovernance(address(roleManager));

        roleManager.setAdmin(admin, true);
        roleManager.setSuperAdmin(superAdmin, true);
    }

    function testSubmitProposalStoresData() external {
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 42);

        governance.submitProposal(address(target), data, 2);

        (uint256 id, address proposalTarget, bytes memory proposalData, uint256 threshold, uint256 weight, bool executed) =
            governance.getProposal(0);

        assertEq(id, 0);
        assertEq(proposalTarget, address(target));
        assertEq(proposalData, data);
        assertEq(threshold, 2);
        assertEq(weight, 0);
        assertEq(executed, false);
    }

    function testApproveProposalAsAdminAddsWeightOne() external {
        governance.submitProposal(address(target), abi.encodeWithSelector(MockTarget.setValue.selector, 1), 1);

        vm.prank(admin);
        governance.approveProposal(0);

        (, , , , uint256 weight, ) = governance.getProposal(0);
        assertEq(weight, 1);
        assertTrue(governance.hasApproved(0, admin));
    }

    function testApproveProposalAsSuperAdminAddsWeightTwo() external {
        governance.submitProposal(address(target), abi.encodeWithSelector(MockTarget.setValue.selector, 1), 2);

        vm.prank(superAdmin);
        governance.approveProposal(0);

        (, , , , uint256 weight, ) = governance.getProposal(0);
        assertEq(weight, 2);
        assertTrue(governance.hasApproved(0, superAdmin));
    }

    function testRevertApproveWhenNotAdminOrSuperAdmin() external {
        governance.submitProposal(address(target), abi.encodeWithSelector(MockTarget.setValue.selector, 1), 1);

        vm.prank(outsider);
        vm.expectRevert("The msg sender must have the admin or the super admin role");
        governance.approveProposal(0);
    }

    function testExecuteProposalAfterThresholdReached() external {
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 77);
        governance.submitProposal(address(target), data, 3);

        vm.prank(admin);
        governance.approveProposal(0);

        vm.prank(superAdmin);
        governance.approveProposal(0);

        governance.executeProposal(0);

        assertEq(target.value(), 77);
        (, , , , , bool executed) = governance.getProposal(0);
        assertTrue(executed);
    }
}
