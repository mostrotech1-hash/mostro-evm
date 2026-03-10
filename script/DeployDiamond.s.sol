// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CommonBase} from "../lib/forge-std/src/Base.sol";
import {Script} from "../lib/forge-std/src/Script.sol";
import {StdChains} from "../lib/forge-std/src/StdChains.sol";
import {StdCheatsSafe} from "../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../lib/forge-std/src/StdUtils.sol";
import {console} from "../lib/forge-std/src/console.sol";
import {Diamond} from "../src/Diamond.sol";
import {ConfigFacet} from "../src/facets/ConfigFacet.sol";
import {DiamondCutFacet} from "../src/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/facets/DiamondLoupeFacet.sol";
import {TestFacet} from "../src/facets/TestFacet.sol";
import {IConfigFacet} from "../src/interfaces/IConfigFacet.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../src/interfaces/IDiamondLoupe.sol";
import {DiamondInit} from "../src/upgradeInitializers/DiamondInit.sol";

/**
 * @title DeployDiamond
 * @notice Adapted from the zip template to follow the CDK project pattern.
 *
 * CHANGES vs original zip script:
 *  1. OwnershipFacet REMOVED — access control handled via role-based storage
 *     seeded in DiamondInit. LibDiamond.contractOwner guards diamondCut() only.
 *  2. DiamondInit now receives a typed InitParams struct.
 *  3. TestFacet selectors updated to match restructured facet.
 */
contract DeployDiamond is Script {

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);

        vm.startBroadcast(pk);

        // ==============================================================
        // PHASE 1: Deploy Core Diamond Infrastructure
        // ==============================================================

        console.log("=== Phase 1: Deploying Diamond Core ===");

        DiamondCutFacet cutFacet = new DiamondCutFacet();
        console.log("DiamondCutFacet:", address(cutFacet));

        Diamond diamond = new Diamond(deployer, address(cutFacet));
        console.log("Diamond:       ", address(diamond));

        // ==============================================================
        // PHASE 2: Deploy Facets
        // NOTE: OwnershipFacet intentionally removed
        // ==============================================================

        console.log("\n=== Phase 2: Deploying Facets ===");

        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();
        ConfigFacet configFacet = new ConfigFacet();
        TestFacet testFacet = new TestFacet();

        console.log("DiamondLoupeFacet:", address(loupeFacet));
        console.log("ConfigFacet:        ", address(configFacet));
        console.log("TestFacet:        ", address(testFacet));

        // ==============================================================
        // PHASE 3: Deploy DiamondInit
        // ==============================================================

        console.log("\n=== Phase 3: Deploying DiamondInit ===");

        DiamondInit diamondInit = new DiamondInit();
        console.log("DiamondInit:      ", address(diamondInit));

        // ==============================================================
        // PHASE 4: Build FacetCut Array
        // ==============================================================

        console.log("\n=== Phase 4: Building FacetCuts ===");

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](3); // ✅ 3 facets

        // --- DiamondLoupe ---
        bytes4[] memory loupeSelectors = new bytes4[](5);
        loupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        loupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;
        loupeSelectors[4] = DiamondLoupeFacet.supportsInterface.selector;

        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(loupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        // --- TestFacet ---
        bytes4[] memory testSelectors = new bytes4[](2);
        testSelectors[0] = TestFacet.setValue.selector;
        testSelectors[1] = TestFacet.getValue.selector;

        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(testFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: testSelectors
        });

        // --- ConfigFacet ---
        bytes4[] memory configSelectors = new bytes4[](2);
        configSelectors[0] = IConfigFacet.getMultisigContract.selector;
        configSelectors[1] = IConfigFacet.setMultisigContract.selector;

        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(configFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: configSelectors
        });

        console.log("FacetCuts prepared: 3 facets");

        // ==============================================================
        // PHASE 5: Execute Atomic DiamondCut with Initialization
        // ==============================================================

        console.log("\n=== Phase 5: Executing DiamondCut ===");

        DiamondInit.InitParams memory params = DiamondInit.InitParams({
            isInit: true
        });

        IDiamondCut(address(diamond)).diamondCut(
            cuts,
            address(diamondInit),
            abi.encodeCall(DiamondInit.init, (params))
        );

        console.log("DiamondCut executed successfully");

        // ==============================================================
        // PHASE 6: Verification
        // ==============================================================

        console.log("\n=== Phase 6: Post-Deployment Verification ===");

        address[] memory facetAddresses =
        IDiamondLoupe(address(diamond)).facetAddresses();
        console.log("Facets installed:", facetAddresses.length);

        vm.stopBroadcast();

        // ==============================================================
        // DEPLOYMENT SUMMARY
        // ==============================================================

        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("Deployer:          ", deployer);
        console.log("Diamond:           ", address(diamond));
        console.log("DiamondCutFacet:   ", address(cutFacet));
        console.log("DiamondLoupeFacet: ", address(loupeFacet));
        console.log("ConfigFacet: ",       address(configFacet));
        console.log("TestFacet:         ", address(testFacet));
        console.log("DiamondInit:       ", address(diamondInit));
        console.log("\nDiamond is ready for use");
    }
}