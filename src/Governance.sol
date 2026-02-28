// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Governance {

    // ─── State Variables ───────────────────────────────────

    mapping(address => bool) private admins;
    mapping(address => bool) private superAdmins;

    uint256 public adminCount;
    uint256 public superAdminCount;

    // ─── Events ───────────────────────────────────────────

    event AdminAdded(address indexed account);
    event AdminRemoved(address indexed account);
    event SuperAdminAdded(address indexed account);
    event SuperAdminRemoved(address indexed account);

    // ─── Errors ───────────────────────────────────────────

    error MustBeANonZeroAddress();
    error AlreadyAnAdmin();
    error AlreadyASuperAdmin();
    error NotAnAdmin();
    error NotASuperAdmin();
    error CannotRemoveLastSuperAdmin();
    error NotAnAdminOrASuperAdmin();

    // ─── Modifiers ────────────────────────────────────────

    modifier onlySuperAdmin() {
        if(!superAdmins[msg.sender]) revert NotASuperAdmin();
        _;
    }

    // ─── Role Lifecycle ───────────────────────────────────

    function addAdmin(address _account) external onlySuperAdmin {
        if(_account == address(0)) revert MustBeANonZeroAddress();
        if(admins[_account]) revert AlreadyAnAdmin();
        if(superAdmins[_account]) revert AlreadyASuperAdmin();

        admins[_account] = true;
        adminCount++;
        emit AdminAdded(_account);        
    }

    function removeAdmin(address _account) external onlySuperAdmin {
        if(!admins[_account]) revert NotAnAdmin();

        admins[_account] = false;
        adminCount--;
        emit AdminRemoved(_account);
    }

    function addSuperAdmin(address _account) external onlySuperAdmin {
        if(_account == address(0)) revert MustBeANonZeroAddress();
        if(admins[_account]) revert AlreadyAnAdmin();
        if(superAdmins[_account]) revert AlreadyASuperAdmin();

        superAdmins[_account] = true;
        superAdminCount++;
        emit SuperAdminAdded(_account);
    }

    function removeSuperAdmin(address _account) external onlySuperAdmin {
        if(!superAdmins[_account]) revert NotASuperAdmin();
        if(superAdminCount <= 1) revert CannotRemoveLastSuperAdmin();
        
        superAdmins[_account] = false;
        superAdminCount--;
        emit SuperAdminRemoved(_account);
    }

    function selfRevoke() external {
        if (superAdmins[msg.sender]) {
            if(superAdminCount <= 1) revert CannotRemoveLastSuperAdmin();
                superAdmins[msg.sender] = false;
                superAdminCount--;
            emit SuperAdminRemoved(msg.sender);
        } else if (admins[msg.sender]) {
                admins[msg.sender] = false;
            emit AdminRemoved(msg.sender);
        } else {
            revert NotAnAdminOrASuperAdmin();
        }
    }

    // ─── Role Queries ────────────────────────────────────────

    function isAdmin(address _account) external view returns (bool) {
        return admins[_account];
    }

    function isSuperAdmin(address _account) external view returns (bool) {
        return superAdmins[_account];
    }

    function getTotalVoteWeight() external view returns (uint256) {
        // Admin (1 vote) + SuperAdmin (2 votes)
        return (adminCount * 1) + (superAdminCount * 2);
    }
}