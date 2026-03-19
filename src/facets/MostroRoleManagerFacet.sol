// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IMostroRoleManager} from '../interfaces/IMostroRoleManager.sol';
import {IMostroStructs} from '../interfaces/IMostroStructs.sol';
import {MostroRoleManagerStorage} from '../libraries/StorageLibraries.sol';

contract MostroRoleManagerFacet is IMostroStructs, IMostroRoleManager {
    
    // ─── Modifiers ────────────────────────────────────────

    modifier onlySuperAdmin() {
        if(!MostroRoleManagerStorage.layout().superAdmins[msg.sender]) revert NotASuperAdmin();
        _;
    }

    constructor() {
        MostroRoleManagerStorage.layout().superAdmins[msg.sender] = true;
        MostroRoleManagerStorage.layout().superAdminCount++;
        emit SuperAdminAdded(msg.sender);
    }

    // ─── Role Lifecycle ───────────────────────────────────

    function addAdmin(address _account) external onlySuperAdmin {
        if(_account == address(0)) revert MustBeANonZeroAddress();
        if(MostroRoleManagerStorage.layout().admins[_account]) revert AlreadyAnAdmin();
        if(MostroRoleManagerStorage.layout().superAdmins[_account]) revert AlreadyASuperAdmin();

        MostroRoleManagerStorage.layout().admins[_account] = true;
        MostroRoleManagerStorage.layout().adminCount++;
        emit AdminAdded(_account);        
    }

    function removeAdmin(address _account) external onlySuperAdmin {
        if(!MostroRoleManagerStorage.layout().admins[_account]) revert NotAnAdmin();

        MostroRoleManagerStorage.layout().admins[_account] = false;
        MostroRoleManagerStorage.layout().adminCount--;
        emit AdminRemoved(_account);
    }

    function addSuperAdmin(address _account) external onlySuperAdmin {
        if(_account == address(0)) revert MustBeANonZeroAddress();
        if(MostroRoleManagerStorage.layout().admins[_account]) revert AlreadyAnAdmin();
        if(MostroRoleManagerStorage.layout().superAdmins[_account]) revert AlreadyASuperAdmin();

        MostroRoleManagerStorage.layout().superAdmins[_account] = true;
        MostroRoleManagerStorage.layout().superAdminCount++;
        emit SuperAdminAdded(_account);
    }

    function removeSuperAdmin(address _account) external onlySuperAdmin {
        if(!MostroRoleManagerStorage.layout().superAdmins[_account]) revert NotASuperAdmin();
        if(MostroRoleManagerStorage.layout().superAdminCount <= 1) revert CannotRemoveLastSuperAdmin();
        
        MostroRoleManagerStorage.layout().superAdmins[_account] = false;
        MostroRoleManagerStorage.layout().superAdminCount--;
        emit SuperAdminRemoved(_account);
    }

    function selfRevoke() external {
        if (MostroRoleManagerStorage.layout().superAdmins[msg.sender]) {
            if(MostroRoleManagerStorage.layout().superAdminCount <= 1) revert CannotRemoveLastSuperAdmin();
            MostroRoleManagerStorage.layout().superAdmins[msg.sender] = false;
            MostroRoleManagerStorage.layout().superAdminCount--;
            emit SuperAdminRemoved(msg.sender);
        } else if (MostroRoleManagerStorage.layout().admins[msg.sender]) {
                    MostroRoleManagerStorage.layout().admins[msg.sender] = false;
                    MostroRoleManagerStorage.layout().adminCount--;
                emit AdminRemoved(msg.sender);
        } else {
            revert NotAnAdminOrASuperAdmin();
        }
    }

    // ─── Role Queries ────────────────────────────────────────

    function isAdmin(address _account) external view returns (bool) {
        return MostroRoleManagerStorage.layout().admins[_account];
    }

    function isSuperAdmin(address _account) external view returns (bool) {
        return MostroRoleManagerStorage.layout().superAdmins[_account];
    }   

    function getTotalVoteWeight() external view returns (uint256) {
        // Admin (1 vote) + SuperAdmin (2 votes)
        return (MostroRoleManagerStorage.layout().adminCount * 1) + (MostroRoleManagerStorage.layout().superAdminCount * 2);
    }

}