// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {IVault, IVaultConfigurator} from "@symbiotic/core/interfaces/IVaultConfigurator.sol";

import "./Imports.sol";

import "./MockStakingRewards.sol";
import {SymbioticContracts} from "./SymbioticContracts.sol";

contract SymbioticHelper {
    struct CreationParams {
        address limitIncreaser;
        address vaultOwner;
        address vaultAdmin;
        uint48 epochDuration;
        address asset;
        uint256 limit;
    }

    SymbioticContracts public immutable symbioticContracts;

    constructor(SymbioticContracts contracts) {
        symbioticContracts = contracts;
    }

    function createNewSymbioticVault(CreationParams memory params)
        public
        returns (address symbioticVault)
    {
        (symbioticVault,,) = IVaultConfigurator(symbioticContracts.VAULT_CONFIGURATOR()).create(
            IVaultConfigurator.InitParams({
                version: 1,
                owner: params.vaultOwner,
                vaultParams: IVault.InitParams({
                    collateral: params.asset,
                    delegator: address(0),
                    slasher: address(0),
                    burner: address(0),
                    epochDuration: params.epochDuration,
                    depositWhitelist: false,
                    isDepositLimit: false,
                    depositLimit: 0,
                    defaultAdminRoleHolder: params.vaultAdmin,
                    depositWhitelistSetRoleHolder: params.vaultAdmin,
                    depositorWhitelistRoleHolder: params.vaultAdmin,
                    isDepositLimitSetRoleHolder: params.vaultAdmin,
                    depositLimitSetRoleHolder: params.vaultAdmin
                }),
                delegatorIndex: 0,
                delegatorParams: hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000009b4e5e7438c17f13bf368d331c864b01b64458bc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000009b4e5e7438c17f13bf368d331c864b01b64458bc00000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000010000000000000000000000009b4e5e7438c17f13bf368d331c864b01b64458bc00000000000000000000000000000000000000000000000000000000000000010000000000000000000000009b4e5e7438c17f13bf368d331c864b01b64458bc",
                withSlasher: false,
                slasherIndex: 0,
                slasherParams: ""
            })
        );
    }

    function createSlashingSymbioticVault(CreationParams memory params)
        public
        returns (address symbioticVault)
    {
        (symbioticVault,,) = IVaultConfigurator(symbioticContracts.VAULT_CONFIGURATOR()).create(
            IVaultConfigurator.InitParams({
                version: 1,
                owner: params.vaultOwner,
                vaultParams: IVault.InitParams({
                    collateral: params.asset,
                    delegator: address(0),
                    slasher: address(0),
                    burner: address(0),
                    epochDuration: params.epochDuration,
                    depositWhitelist: false,
                    isDepositLimit: false,
                    depositLimit: 0,
                    defaultAdminRoleHolder: params.vaultAdmin,
                    depositWhitelistSetRoleHolder: params.vaultAdmin,
                    depositorWhitelistRoleHolder: params.vaultAdmin,
                    isDepositLimitSetRoleHolder: params.vaultAdmin,
                    depositLimitSetRoleHolder: params.vaultAdmin
                }),
                delegatorIndex: 0,
                delegatorParams: hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000009b4e5e7438c17f13bf368d331c864b01b64458bc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000009b4e5e7438c17f13bf368d331c864b01b64458bc00000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000010000000000000000000000009b4e5e7438c17f13bf368d331c864b01b64458bc00000000000000000000000000000000000000000000000000000000000000010000000000000000000000009b4e5e7438c17f13bf368d331c864b01b64458bc",
                withSlasher: true,
                slasherIndex: 0,
                slasherParams: hex"00000000000000000000000000000000000000000000000000000000000151800000000000000000000000000000000000000000000000000000000000000003"
            })
        );
    }

    function createFarms(address /* rewardToken */ )
        public
        returns (address symbioticFarm, address distributionFarm)
    {
        symbioticFarm = address(new MockStakingRewards());
        distributionFarm = address(new MockStakingRewards());
    }

    function test() external pure {}
}
