// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./Imports.sol";
import "./MockStakingRewards.sol";

import {IDelegatorFactory} from "@symbiotic/core/interfaces/IDelegatorFactory.sol";
import {INetworkRegistry} from "@symbiotic/core/interfaces/INetworkRegistry.sol";
import {IOperatorRegistry} from "@symbiotic/core/interfaces/IOperatorRegistry.sol";
import {ISlasherFactory} from "@symbiotic/core/interfaces/ISlasherFactory.sol";
import {IVaultConfigurator} from "@symbiotic/core/interfaces/IVaultConfigurator.sol";
import {IVaultFactory} from "@symbiotic/core/interfaces/IVaultFactory.sol";
import {
    IBaseDelegator,
    IFullRestakeDelegator
} from "@symbiotic/core/interfaces/delegator/IFullRestakeDelegator.sol";

import {IVaultConfigurator} from "@symbiotic/core/interfaces/IVaultConfigurator.sol";
import {INetworkMiddlewareService} from
    "@symbiotic/core/interfaces/service/INetworkMiddlewareService.sol";
import {ISlasher} from "@symbiotic/core/interfaces/slasher/ISlasher.sol";
import {
    IBaseSlasher,
    IVetoSlasher as ISymbioticVetoSlasher
} from "@symbiotic/core/interfaces/slasher/IVetoSlasher.sol";
import {IVault} from "@symbiotic/core/interfaces/vault/IVault.sol";

import {DefaultStakerRewards} from
    "@symbiotic/rewards/contracts/defaultStakerRewards/DefaultStakerRewards.sol";
import {IDefaultStakerRewards} from
    "@symbiotic/rewards/interfaces/defaultStakerRewards/IDefaultStakerRewards.sol";

import "./Constants.sol";

import "forge-std/console2.sol";

contract SymbioticHelper {
    struct CreationParams {
        address vaultOwner;
        address vaultAdmin;
        uint48 epochDuration;
        address asset;
        bool isDepositLimit;
        uint256 depositLimit;
    }

    struct CreationParamsExtended {
        address vaultOwner;
        address vaultAdmin;
        address burner;
        uint48 epochDuration;
        address asset;
        bool isDepositLimit;
        uint256 depositLimit;
    }

    Constants.SymbioticDeployment private deployment;

    function getSymbioticDeployment() public view returns (Constants.SymbioticDeployment memory) {
        return deployment;
    }

    function finalizeDeployment() private {
        deployment = Constants.symbioticDeployment();
    }

    constructor() {
        finalizeDeployment();
    }

    function generateAddress(string memory salt) private view returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(salt, address(this))))));
    }

    function createNewSymbioticVault(CreationParamsExtended memory params)
        public
        returns (address symbioticVault)
    {
        IFullRestakeDelegator.InitParams memory initParams = IFullRestakeDelegator.InitParams({
            baseParams: IBaseDelegator.BaseParams({
                defaultAdminRoleHolder: generateAddress("defaultAdminRoleHolder"),
                hook: address(0),
                hookSetRoleHolder: generateAddress("hookSetRoleHolder")
            }),
            networkLimitSetRoleHolders: new address[](0),
            operatorNetworkLimitSetRoleHolders: new address[](0)
        });
        (symbioticVault,,) = IVaultConfigurator(getSymbioticDeployment().vaultConfigurator).create(
            IVaultConfigurator.InitParams({
                version: 1,
                owner: params.vaultOwner,
                vaultParams: abi.encode(
                    IVault.InitParams({
                        collateral: params.asset,
                        burner: params.burner,
                        epochDuration: params.epochDuration,
                        depositWhitelist: false,
                        isDepositLimit: params.isDepositLimit,
                        depositLimit: params.depositLimit,
                        defaultAdminRoleHolder: params.vaultAdmin,
                        depositWhitelistSetRoleHolder: params.vaultAdmin,
                        depositorWhitelistRoleHolder: params.vaultAdmin,
                        isDepositLimitSetRoleHolder: params.vaultAdmin,
                        depositLimitSetRoleHolder: params.vaultAdmin
                    })
                ),
                delegatorIndex: 0,
                delegatorParams: abi.encode(initParams),
                withSlasher: false,
                slasherIndex: 0,
                slasherParams: ""
            })
        );
    }

    function createNewSymbioticVault(CreationParams memory params)
        public
        returns (address symbioticVault)
    {
        IFullRestakeDelegator.InitParams memory initParams = IFullRestakeDelegator.InitParams({
            baseParams: IBaseDelegator.BaseParams({
                defaultAdminRoleHolder: generateAddress("defaultAdminRoleHolder"),
                hook: address(0),
                hookSetRoleHolder: generateAddress("hookSetRoleHolder")
            }),
            networkLimitSetRoleHolders: new address[](0),
            operatorNetworkLimitSetRoleHolders: new address[](0)
        });
        (symbioticVault,,) = IVaultConfigurator(getSymbioticDeployment().vaultConfigurator).create(
            IVaultConfigurator.InitParams({
                version: 1,
                owner: params.vaultOwner,
                vaultParams: abi.encode(
                    IVault.InitParams({
                        collateral: params.asset,
                        burner: address(0),
                        epochDuration: params.epochDuration,
                        depositWhitelist: false,
                        isDepositLimit: params.isDepositLimit,
                        depositLimit: params.depositLimit,
                        defaultAdminRoleHolder: params.vaultAdmin,
                        depositWhitelistSetRoleHolder: params.vaultAdmin,
                        depositorWhitelistRoleHolder: params.vaultAdmin,
                        isDepositLimitSetRoleHolder: params.vaultAdmin,
                        depositLimitSetRoleHolder: params.vaultAdmin
                    })
                ),
                delegatorIndex: 0,
                delegatorParams: abi.encode(initParams),
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
        IFullRestakeDelegator.InitParams memory initParams = IFullRestakeDelegator.InitParams({
            baseParams: IBaseDelegator.BaseParams({
                defaultAdminRoleHolder: generateAddress("defaultAdminRoleHolder"),
                hook: address(0),
                hookSetRoleHolder: generateAddress("hookSetRoleHolder")
            }),
            networkLimitSetRoleHolders: new address[](0),
            operatorNetworkLimitSetRoleHolders: new address[](0)
        });

        (symbioticVault,,) = IVaultConfigurator(getSymbioticDeployment().vaultConfigurator).create(
            IVaultConfigurator.InitParams({
                version: 1,
                owner: params.vaultOwner,
                vaultParams: abi.encode(
                    IVault.InitParams({
                        collateral: params.asset,
                        burner: address(0),
                        epochDuration: params.epochDuration,
                        depositWhitelist: false,
                        isDepositLimit: params.isDepositLimit,
                        depositLimit: params.depositLimit,
                        defaultAdminRoleHolder: params.vaultAdmin,
                        depositWhitelistSetRoleHolder: params.vaultAdmin,
                        depositorWhitelistRoleHolder: params.vaultAdmin,
                        isDepositLimitSetRoleHolder: params.vaultAdmin,
                        depositLimitSetRoleHolder: params.vaultAdmin
                    })
                ),
                delegatorIndex: 0,
                delegatorParams: abi.encode(initParams),
                withSlasher: true,
                slasherIndex: 0,
                slasherParams: abi.encode(
                    ISymbioticVetoSlasher.InitParams({
                        baseParams: IBaseSlasher.BaseParams({isBurnerHook: false}),
                        vetoDuration: 1 hours,
                        resolverSetEpochsDelay: 3
                    })
                )
            })
        );
    }

    function createFarms(address)
        public
        returns (address symbioticFarm, address distributionFarm)
    {
        symbioticFarm = address(new MockStakingRewards());
        distributionFarm = address(new MockStakingRewards());
    }

    function test() external pure {}
}
