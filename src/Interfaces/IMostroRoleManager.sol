// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMostroRoleManager {

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
    error AlreadyInitialized();

    // ─── Role Lifecycle ───────────────────────────────────

    function addAdmin(address _account) external;
    function removeAdmin(address _account) external;
    function addSuperAdmin(address _account) external;
    function removeSuperAdmin(address _account) external;
    function selfRevoke() external;

    // ─── Role Queries ─────────────────────────────────────

    function isAdmin(address _account) external view returns (bool);
    function isSuperAdmin(address _account) external view returns (bool);
    function getTotalVoteWeight() external view returns (uint256);

    // ─── State Variables ──────────────────────────────────

    // function adminCount() external view returns (uint256);
    // function superAdminCount() external view returns (uint256);

}