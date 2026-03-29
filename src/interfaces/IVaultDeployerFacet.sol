// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IMostroStructs} from "./IMostroStructs.sol";

interface IVaultDeployerFacet is IMostroStructs {
    event VaultsDeployed(
        address indexed deployer,
        address indexed multisig,
        address indexed platformContract,
        address artistUnvestedVault,
        address artistRevenueVault,
        address lpVault,
        address mostroGenesisWallet,
        address platformUsdcTreasury,
        address publicPoolVault,
        address streamFlowEscrowVault,
        address unlockedSaleVault
    );

    event TokenAllocationDistributed(
        address indexed platformContract,
        address indexed token,
        uint256 totalAmount,
        uint256 publicPoolAmount,
        uint256 streamFlowAmount,
        uint256 mostroGenesisAmount,
        uint256 lpVaultAmount
    );

    error ZeroAddress();
    error InvalidContractAddress(address addr);
    error DeploymentAlreadyExists(address platformContract);
    error InvalidTokenAmount();

    /// @param fundingContract When `totalTokenAmount > 0`, tokens are pulled from this address
    ///        via `transferFrom` (must approve the Diamond first). Ignored when amount is 0.
    function deployAllVaults(
        address multisig,
        address token,
        address usdc,
        address platformContract,
        address artist,
        address fundingContract,
        uint256 totalTokenAmount
    ) external returns (DeployedVaults memory vaults);

    function getDeploymentByPlatformContract(
        address platformContract
    ) external view returns (DeployedVaults memory vaults);
}
