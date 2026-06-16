// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {Diamond}           from "src/Diamond.sol";
import {DiamondCutFacet}   from "src/facets/DiamondCutFacet.sol";
import {ConfigFacet}       from "src/facets/ConfigFacet.sol";
import {MostroFactoryFacet} from "src/facets/MostroFactoryFacet.sol";

import {IDiamondCut}    from "src/interfaces/IDiamondCut.sol";
import {IConfigFacet}   from "src/interfaces/IConfigFacet.sol";
import {IMostroFactory} from "src/interfaces/IMostroFactory.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockArtistToken is ERC20 {
    constructor() ERC20("Artist Token", "ART") {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

/**
 * @dev Full Diamond fixture for MostroFactoryFacet tests.
 *      Roles are seeded via vm.store to avoid a separate role-manager facet dependency.
 */
contract MostroFactoryFacetTest is Test {

    event PublicPoolVaultCreated(address indexed tokenAddress, address indexed vaultAddress);
    event StreamflowEscrowVaultCreated(address indexed tokenAddress, address indexed vaultAddress);
    event LPVaultCreated(address indexed tokenAddress, address indexed vaultAddress);
    event GenesisVaultCreated(address indexed tokenAddress, address indexed vaultAddress);

    // ─── Diamond ──────────────────────────────────────────────────────────────

    Diamond            internal diamond;
    DiamondCutFacet    internal cutFacet;
    ConfigFacet        internal configFacetImpl;
    MostroFactoryFacet internal factoryFacetImpl;
    IConfigFacet   internal config;
    IMostroFactory internal factory;
    IDiamondCut    internal cut;

    // ─── Actors ───────────────────────────────────────────────────────────────

    address internal admin    = makeAddr("admin");
    address internal superAdm = makeAddr("superAdmin");
    address internal multisig = makeAddr("multisig");
    address internal nobody   = makeAddr("nobody");

    // ─── Token ────────────────────────────────────────────────────────────────

    MockArtistToken internal token;
    uint256 internal constant SUPPLY    = 1_000_000e18;
    bytes32 internal constant ARTIST_ID = keccak256("test-artist");

    // ─── Setup ────────────────────────────────────────────────────────────────

    function setUp() external {
        _deployDiamond();
        _wireFacets();
        _setupConfig();
        _grantAdmin(admin);
        _grantSuperAdmin(superAdm);
        _mintTokenToDiamond(SUPPLY);
    }

    function _deployDiamond() private {
        cutFacet       = new DiamondCutFacet();
        diamond        = new Diamond(address(this), address(cutFacet));
        cut            = IDiamondCut(address(diamond));
        configFacetImpl  = new ConfigFacet();
        factoryFacetImpl = new MostroFactoryFacet();
    }

    function _wireFacets() private {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](2);

        bytes4[] memory configSelectors = new bytes4[](2);
        configSelectors[0] = IConfigFacet.getMultisigContract.selector;
        configSelectors[1] = IConfigFacet.setMultisigContract.selector;
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(configFacetImpl),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: configSelectors
        });

        bytes4[] memory factorySelectors = new bytes4[](6);
        factorySelectors[0] = MostroFactoryFacet.initializeColdVaults.selector;
        factorySelectors[1] = MostroFactoryFacet.getArtistToken.selector;
        factorySelectors[2] = MostroFactoryFacet.getPublicPoolVault.selector;
        factorySelectors[3] = MostroFactoryFacet.getStreamflowEscrowVault.selector;
        factorySelectors[4] = MostroFactoryFacet.getLPVault.selector;
        factorySelectors[5] = MostroFactoryFacet.getGenesisVault.selector;
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(factoryFacetImpl),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: factorySelectors
        });

        cut.diamondCut(cuts, address(0), "");
        config  = IConfigFacet(address(diamond));
        factory = IMostroFactory(address(diamond));
    }

    function _setupConfig() private {
        config.setMultisigContract(multisig);
    }

    function _mintTokenToDiamond(uint256 amount) private {
        token = new MockArtistToken();
        token.mint(address(diamond), amount);
    }

    /**
     * @dev Seeds admins[account] = true in Diamond storage.
     *      MostroRoleManagerLayout slot layout:
     *        BASE+0 → mapping admins
     *        BASE+1 → mapping superAdmins
     */
    function _grantAdmin(address account) internal {
        bytes32 base     = keccak256("mostro.storage.mostro.role.manager");
        bytes32 valueSlot = keccak256(abi.encode(account, base));
        vm.store(address(diamond), valueSlot, bytes32(uint256(1)));
    }

    function _grantSuperAdmin(address account) internal {
        bytes32 base          = keccak256("mostro.storage.mostro.role.manager");
        bytes32 superAdminSlot = bytes32(uint256(base) + 1);
        bytes32 valueSlot      = keccak256(abi.encode(account, superAdminSlot));
        vm.store(address(diamond), valueSlot, bytes32(uint256(1)));
    }

    function _defaultHotVaults() private pure returns (address, address, address, address) {
        return (address(0x1), address(0x2), address(0x3), address(0x4));
    }

    // ─── happy path ──────────────────────────────────────────────────────────

    function test_initializeColdVaults_deploysAllFourVaults() external {
        (address pp, address sf, address lp, address gen) = _defaultHotVaults();
        vm.prank(admin);
        factory.initializeColdVaults(ARTIST_ID, address(token), SUPPLY, pp, sf, lp, gen);

        assertTrue(factory.getPublicPoolVault(address(token))        != address(0));
        assertTrue(factory.getStreamflowEscrowVault(address(token))  != address(0));
        assertTrue(factory.getLPVault(address(token))                != address(0));
        assertTrue(factory.getGenesisVault(address(token))           != address(0));
    }

    function test_initializeColdVaults_registersArtistToken() external {
        (address pp, address sf, address lp, address gen) = _defaultHotVaults();
        vm.prank(admin);
        factory.initializeColdVaults(ARTIST_ID, address(token), SUPPLY, pp, sf, lp, gen);
        assertEq(factory.getArtistToken(ARTIST_ID), address(token));
    }

    function test_initializeColdVaults_diamondHoldsZeroAfter() external {
        (address pp, address sf, address lp, address gen) = _defaultHotVaults();
        vm.prank(admin);
        factory.initializeColdVaults(ARTIST_ID, address(token), SUPPLY, pp, sf, lp, gen);
        assertEq(token.balanceOf(address(diamond)), 0);
    }

    function test_initializeColdVaults_totalAllocationsEqualSupply() external {
        (address pp, address sf, address lp, address gen) = _defaultHotVaults();
        vm.prank(admin);
        factory.initializeColdVaults(ARTIST_ID, address(token), SUPPLY, pp, sf, lp, gen);

        uint256 bal_pp  = token.balanceOf(factory.getPublicPoolVault(address(token)));
        uint256 bal_sf  = token.balanceOf(factory.getStreamflowEscrowVault(address(token)));
        uint256 bal_lp  = token.balanceOf(factory.getLPVault(address(token)));
        uint256 bal_gen = token.balanceOf(factory.getGenesisVault(address(token)));

        assertEq(bal_pp + bal_sf + bal_lp + bal_gen, SUPPLY);
    }

    function test_initializeColdVaults_allocationsMatchBps() external {
        (address pp, address sf, address lp, address gen) = _defaultHotVaults();
        vm.prank(admin);
        factory.initializeColdVaults(ARTIST_ID, address(token), SUPPLY, pp, sf, lp, gen);

        assertEq(token.balanceOf(factory.getPublicPoolVault(address(token))),       (SUPPLY * 4500) / 10000);
        assertEq(token.balanceOf(factory.getStreamflowEscrowVault(address(token))), (SUPPLY * 4700) / 10000);
        assertEq(token.balanceOf(factory.getLPVault(address(token))),               (SUPPLY * 500)  / 10000);
    }

    function test_initializeColdVaults_genesisAbsorbsRoundingDust() external {
        // Use an odd supply so integer division produces dust.
        MockArtistToken oddToken = new MockArtistToken();
        uint256 oddSupply = 1_000_003e18;
        oddToken.mint(address(diamond), oddSupply);

        (address pp, address sf, address lp, address gen) = _defaultHotVaults();
        vm.prank(admin);
        factory.initializeColdVaults(keccak256("odd-artist"), address(oddToken), oddSupply, pp, sf, lp, gen);

        uint256 ppAlloc  = (oddSupply * 4500) / 10000;
        uint256 sfAlloc  = (oddSupply * 4700) / 10000;
        uint256 lpAlloc  = (oddSupply * 500)  / 10000;
        uint256 expected = oddSupply - ppAlloc - sfAlloc - lpAlloc;

        assertEq(oddToken.balanceOf(factory.getGenesisVault(address(oddToken))), expected);
    }

    function test_initializeColdVaults_emitsFourEvents() external {
        (address pp, address sf, address lp, address gen) = _defaultHotVaults();
        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit PublicPoolVaultCreated(address(token), address(0));
        vm.expectEmit(true, false, false, false);
        emit StreamflowEscrowVaultCreated(address(token), address(0));
        vm.expectEmit(true, false, false, false);
        emit LPVaultCreated(address(token), address(0));
        vm.expectEmit(true, false, false, false);
        emit GenesisVaultCreated(address(token), address(0));
        factory.initializeColdVaults(ARTIST_ID, address(token), SUPPLY, pp, sf, lp, gen);
    }

    // ─── access control ───────────────────────────────────────────────────────

    function test_initializeColdVaults_revertsForUnknownCaller() external {
        (address pp, address sf, address lp, address gen) = _defaultHotVaults();
        vm.prank(nobody);
        vm.expectRevert(IMostroFactory.Unauthorized.selector);
        factory.initializeColdVaults(ARTIST_ID, address(token), SUPPLY, pp, sf, lp, gen);
    }

    function test_initializeColdVaults_adminCanCall() external {
        (address pp, address sf, address lp, address gen) = _defaultHotVaults();
        vm.prank(admin);
        factory.initializeColdVaults(ARTIST_ID, address(token), SUPPLY, pp, sf, lp, gen);
        assertEq(factory.getArtistToken(ARTIST_ID), address(token));
    }

    function test_initializeColdVaults_superAdminCanCall() external {
        (address pp, address sf, address lp, address gen) = _defaultHotVaults();
        vm.prank(superAdm);
        factory.initializeColdVaults(ARTIST_ID, address(token), SUPPLY, pp, sf, lp, gen);
        assertEq(factory.getArtistToken(ARTIST_ID), address(token));
    }

    // ─── input validation ─────────────────────────────────────────────────────

    function test_initializeColdVaults_revertsOnZeroArtistId() external {
        (address pp, address sf, address lp, address gen) = _defaultHotVaults();
        vm.prank(admin);
        vm.expectRevert(IMostroFactory.InvalidArtistId.selector);
        factory.initializeColdVaults(bytes32(0), address(token), SUPPLY, pp, sf, lp, gen);
    }

    function test_initializeColdVaults_revertsOnZeroTotalSupply() external {
        (address pp, address sf, address lp, address gen) = _defaultHotVaults();
        vm.prank(admin);
        vm.expectRevert(IMostroFactory.InvalidTotalSupply.selector);
        factory.initializeColdVaults(ARTIST_ID, address(token), 0, pp, sf, lp, gen);
    }

    function test_initializeColdVaults_revertsOnZeroTokenAddress() external {
        (address pp, address sf, address lp, address gen) = _defaultHotVaults();
        vm.prank(admin);
        vm.expectRevert(IMostroFactory.MustBeANonZeroAddress.selector);
        factory.initializeColdVaults(ARTIST_ID, address(0), SUPPLY, pp, sf, lp, gen);
    }

    function test_initializeColdVaults_revertsOnZeroPublicPoolHotVault() external {
        (, address sf, address lp, address gen) = _defaultHotVaults();
        vm.prank(admin);
        vm.expectRevert(IMostroFactory.MustBeANonZeroAddress.selector);
        factory.initializeColdVaults(ARTIST_ID, address(token), SUPPLY, address(0), sf, lp, gen);
    }

    function test_initializeColdVaults_revertsOnZeroStreamflowHotVault() external {
        (address pp,, address lp, address gen) = _defaultHotVaults();
        vm.prank(admin);
        vm.expectRevert(IMostroFactory.MustBeANonZeroAddress.selector);
        factory.initializeColdVaults(ARTIST_ID, address(token), SUPPLY, pp, address(0), lp, gen);
    }

    function test_initializeColdVaults_revertsOnZeroLPHotVault() external {
        (address pp, address sf,, address gen) = _defaultHotVaults();
        vm.prank(admin);
        vm.expectRevert(IMostroFactory.MustBeANonZeroAddress.selector);
        factory.initializeColdVaults(ARTIST_ID, address(token), SUPPLY, pp, sf, address(0), gen);
    }

    function test_initializeColdVaults_revertsOnZeroGenesisHotVault() external {
        (address pp, address sf, address lp,) = _defaultHotVaults();
        vm.prank(admin);
        vm.expectRevert(IMostroFactory.MustBeANonZeroAddress.selector);
        factory.initializeColdVaults(ARTIST_ID, address(token), SUPPLY, pp, sf, lp, address(0));
    }

    // ─── business logic ───────────────────────────────────────────────────────

    function test_initializeColdVaults_revertsIfArtistAlreadyExists() external {
        (address pp, address sf, address lp, address gen) = _defaultHotVaults();
        vm.startPrank(admin);
        factory.initializeColdVaults(ARTIST_ID, address(token), SUPPLY, pp, sf, lp, gen);
        vm.expectRevert(IMostroFactory.ArtistAlreadyExists.selector);
        factory.initializeColdVaults(ARTIST_ID, address(token), SUPPLY, pp, sf, lp, gen);
        vm.stopPrank();
    }

    function test_initializeColdVaults_revertsOnTotalSupplyMismatch() external {
        (address pp, address sf, address lp, address gen) = _defaultHotVaults();
        vm.prank(admin);
        vm.expectRevert(IMostroFactory.TotalSupplyMismatch.selector);
        factory.initializeColdVaults(ARTIST_ID, address(token), SUPPLY + 1, pp, sf, lp, gen);
    }

    function test_initializeColdVaults_revertsOnInsufficientBalance() external {
        // Diamond only holds half the total supply.
        MockArtistToken splitToken = new MockArtistToken();
        uint256 half = SUPPLY / 2;
        splitToken.mint(address(diamond), half);
        splitToken.mint(address(this),    half); // other half NOT in diamond

        (address pp, address sf, address lp, address gen) = _defaultHotVaults();
        vm.prank(admin);
        vm.expectRevert(IMostroFactory.InsufficientTokenBalance.selector);
        factory.initializeColdVaults(ARTIST_ID, address(splitToken), SUPPLY, pp, sf, lp, gen);
    }

    function test_initializeColdVaults_revertsIfMultisigNotSet() external {
        // Deploy a fresh Diamond with factory wired but no multisig configured.
        DiamondCutFacet    freshCut     = new DiamondCutFacet();
        Diamond            freshDiamond = new Diamond(address(this), address(freshCut));
        ConfigFacet        freshConfig  = new ConfigFacet();
        MostroFactoryFacet freshFactory = new MostroFactoryFacet();

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](2);

        bytes4[] memory cfgSel = new bytes4[](2);
        cfgSel[0] = IConfigFacet.getMultisigContract.selector;
        cfgSel[1] = IConfigFacet.setMultisigContract.selector;
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(freshConfig),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: cfgSel
        });

        bytes4[] memory facSel = new bytes4[](6);
        facSel[0] = MostroFactoryFacet.initializeColdVaults.selector;
        facSel[1] = MostroFactoryFacet.getArtistToken.selector;
        facSel[2] = MostroFactoryFacet.getPublicPoolVault.selector;
        facSel[3] = MostroFactoryFacet.getStreamflowEscrowVault.selector;
        facSel[4] = MostroFactoryFacet.getLPVault.selector;
        facSel[5] = MostroFactoryFacet.getGenesisVault.selector;
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(freshFactory),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: facSel
        });

        IDiamondCut(address(freshDiamond)).diamondCut(cuts, address(0), "");

        MockArtistToken freshToken = new MockArtistToken();
        freshToken.mint(address(freshDiamond), SUPPLY);

        _grantAdminOn(admin, address(freshDiamond));

        (address pp, address sf, address lp, address gen) = _defaultHotVaults();
        vm.prank(admin);
        vm.expectRevert(IMostroFactory.MustBeANonZeroAddress.selector);
        IMostroFactory(address(freshDiamond)).initializeColdVaults(
            ARTIST_ID, address(freshToken), SUPPLY, pp, sf, lp, gen
        );
    }

    // ─── view functions ───────────────────────────────────────────────────────

    function test_getArtistToken_returnsZeroBeforeInit() external view {
        assertEq(factory.getArtistToken(keccak256("unknown")), address(0));
    }

    function test_getPublicPoolVault_returnsZeroBeforeInit() external view {
        assertEq(factory.getPublicPoolVault(address(token)), address(0));
    }

    function test_getStreamflowEscrowVault_returnsZeroBeforeInit() external view {
        assertEq(factory.getStreamflowEscrowVault(address(token)), address(0));
    }

    function test_getLPVault_returnsZeroBeforeInit() external view {
        assertEq(factory.getLPVault(address(token)), address(0));
    }

    function test_getGenesisVault_returnsZeroBeforeInit() external view {
        assertEq(factory.getGenesisVault(address(token)), address(0));
    }

    // ─── Internal helpers ─────────────────────────────────────────────────────

    function _grantAdminOn(address account, address target) internal {
        bytes32 base      = keccak256("mostro.storage.mostro.role.manager");
        bytes32 valueSlot = keccak256(abi.encode(account, base));
        vm.store(target, valueSlot, bytes32(uint256(1)));
    }
}
