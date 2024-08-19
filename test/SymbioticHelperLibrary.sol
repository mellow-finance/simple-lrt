// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./Imports.sol";

import "./MockStakingRewards.sol";
import "./SymbioticConstants.sol";

interface IDefaultCollateralFactory {
    function create(address asset, uint256 initialLimit, address limitIncreaser)
        external
        returns (address);
}

interface IVaultConfigurator {
    struct SymbioticVaultInitParams {
        address collateral;
        address delegator;
        address slasher;
        address burner;
        uint48 epochDuration;
        bool depositWhitelist;
        address defaultAdminRoleHolder;
        address depositWhitelistSetRoleHolder;
        address depositorWhitelistRoleHolder;
    }

    struct InitParams {
        uint64 version;
        address owner;
        SymbioticVaultInitParams vaultParams;
        uint64 delegatorIndex;
        bytes delegatorParams;
        bool withSlasher;
        uint64 slasherIndex;
        bytes slasherParams;
    }

    function create(InitParams memory params) external returns (address, address, address);
}

library SymbioticHelperLibrary {
    struct CreationParams {
        address limitIncreaser;
        address vaultOwner;
        address vaultAdmin;
        uint48 epochDuration;
        address asset;
        uint256 limit;
    }

    function createNewSymbioticVault(CreationParams memory params)
        public
        returns (address symbioticVault)
    {
        address collateral = IDefaultCollateralFactory(SymbioticConstants.COLLATERAL_FACTORY).create(
            params.asset, params.limit, params.limitIncreaser
        );

        (symbioticVault,,) = IVaultConfigurator(SymbioticConstants.VAULT_CONFIGURATOR).create(
            IVaultConfigurator.InitParams({
                version: 1,
                owner: params.vaultOwner,
                vaultParams: IVaultConfigurator.SymbioticVaultInitParams({
                    collateral: address(collateral),
                    delegator: address(0),
                    slasher: address(0),
                    burner: address(0),
                    epochDuration: params.epochDuration,
                    depositWhitelist: false,
                    defaultAdminRoleHolder: params.vaultAdmin,
                    depositWhitelistSetRoleHolder: params.vaultAdmin,
                    depositorWhitelistRoleHolder: params.vaultAdmin
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
        address collateral = IDefaultCollateralFactory(SymbioticConstants.COLLATERAL_FACTORY).create(
            params.asset, params.limit, params.limitIncreaser
        );

        (symbioticVault,,) = IVaultConfigurator(SymbioticConstants.VAULT_CONFIGURATOR).create(
            IVaultConfigurator.InitParams({
                version: 1,
                owner: params.vaultOwner,
                vaultParams: IVaultConfigurator.SymbioticVaultInitParams({
                    collateral: address(collateral),
                    delegator: address(0),
                    slasher: address(0),
                    burner: address(0),
                    epochDuration: params.epochDuration,
                    depositWhitelist: false,
                    defaultAdminRoleHolder: params.vaultAdmin,
                    depositWhitelistSetRoleHolder: params.vaultAdmin,
                    depositorWhitelistRoleHolder: params.vaultAdmin
                }),
                delegatorIndex: 0,
                delegatorParams: hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000009b4e5e7438c17f13bf368d331c864b01b64458bc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000009b4e5e7438c17f13bf368d331c864b01b64458bc00000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000010000000000000000000000009b4e5e7438c17f13bf368d331c864b01b64458bc00000000000000000000000000000000000000000000000000000000000000010000000000000000000000009b4e5e7438c17f13bf368d331c864b01b64458bc",
                withSlasher: true,
                slasherIndex: 1,
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
