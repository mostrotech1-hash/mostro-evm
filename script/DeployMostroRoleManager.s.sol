// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MostroRoleManager.sol";

contract DeployMostroRoleManager is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address initialSuperAdmin = vm.envAddress("INITIAL_SUPER_ADMIN");

        vm.startBroadcast(privateKey);

        MostroRoleManager roleManager = new MostroRoleManager(initialSuperAdmin);

        vm.stopBroadcast();

        console.log("MostroRoleManager deployed at:", address(roleManager));
        console.log("Initial SuperAdmin set to:", initialSuperAdmin);
    }
}