// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./Imports.sol";
import "./MockStakingRewards.sol";

import {DelegatorFactory} from "@symbiotic/core/contracts/DelegatorFactory.sol";
import {NetworkRegistry} from "@symbiotic/core/contracts/NetworkRegistry.sol";
import {OperatorRegistry} from "@symbiotic/core/contracts/OperatorRegistry.sol";
import {SlasherFactory} from "@symbiotic/core/contracts/SlasherFactory.sol";
import {VaultConfigurator} from "@symbiotic/core/contracts/VaultConfigurator.sol";
import {VaultFactory} from "@symbiotic/core/contracts/VaultFactory.sol";
import {
    FullRestakeDelegator,
    IBaseDelegator,
    IFullRestakeDelegator
} from "@symbiotic/core/contracts/delegator/FullRestakeDelegator.sol";

import {NetworkMiddlewareService} from
    "@symbiotic/core/contracts/service/NetworkMiddlewareService.sol";
import {Slasher} from "@symbiotic/core/contracts/slasher/Slasher.sol";
import {Vault} from "@symbiotic/core/contracts/vault/Vault.sol";

import {IVaultConfigurator} from "@symbiotic/core/interfaces/IVaultConfigurator.sol";
import {IVault} from "@symbiotic/core/interfaces/vault/IVault.sol";

contract SymbioticHelper {
    struct SymbioticDeployment {
        address networkRegistry;
        address operatorRegistry;
        address vaultFactory;
        address delegatorFactory;
        address slasherFactory;
        address vaultConfigurator;
        address networkMiddlewareService;
        address operatorVaultOptInService;
        address operatorNetworkOptInService;
    }

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

    SymbioticDeployment private deployment;

    function getSymbioticDeployment() public view returns (SymbioticDeployment memory) {
        return deployment;
    }

    function finalizeDeployment() private {
        address this_ = address(this);
        deployment.networkRegistry = address(new NetworkRegistry());
        deployment.operatorRegistry = address(new OperatorRegistry());
        deployment.vaultFactory = address(new VaultFactory(this_));
        deployment.delegatorFactory = address(new DelegatorFactory(this_));
        deployment.slasherFactory = address(new SlasherFactory(this_));
        deployment.vaultConfigurator = address(
            new VaultConfigurator(
                deployment.vaultFactory, deployment.delegatorFactory, deployment.slasherFactory
            )
        );

        deployment.networkMiddlewareService =
            address(new NetworkMiddlewareService(deployment.networkRegistry));

        VaultFactory(deployment.vaultFactory).whitelist(
            address(
                new Vault(
                    deployment.delegatorFactory, deployment.slasherFactory, deployment.vaultFactory
                )
            )
        );

        DelegatorFactory(deployment.delegatorFactory).whitelist(
            address(
                new FullRestakeDelegator(
                    deployment.networkRegistry,
                    deployment.vaultFactory,
                    deployment.operatorVaultOptInService,
                    deployment.operatorNetworkOptInService,
                    deployment.delegatorFactory,
                    uint64(0)
                )
            )
        );

        SlasherFactory(deployment.slasherFactory).whitelist(
            address(
                new Slasher(
                    deployment.vaultFactory,
                    deployment.networkMiddlewareService,
                    deployment.slasherFactory,
                    uint64(0)
                )
            )
        );
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
                slasherParams: new bytes(0)
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
