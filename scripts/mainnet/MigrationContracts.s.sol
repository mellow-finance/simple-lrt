// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {EthWrapper} from "../../src/EthWrapper.sol";
import {MellowVaultCompat} from "../../src/MellowVaultCompat.sol";
import {Migrator} from "../../src/Migrator.sol";

import {INetworkRegistry} from "@symbiotic/core/interfaces/INetworkRegistry.sol";
import {IOperatorRegistry} from "@symbiotic/core/interfaces/IOperatorRegistry.sol";
import {ISlasherFactory} from "@symbiotic/core/interfaces/ISlasherFactory.sol";
import {IVaultConfigurator} from "@symbiotic/core/interfaces/IVaultConfigurator.sol";
import {IVaultFactory} from "@symbiotic/core/interfaces/IVaultFactory.sol";
import {IBaseDelegator} from "@symbiotic/core/interfaces/delegator/IBaseDelegator.sol";
import {IFullRestakeDelegator} from "@symbiotic/core/interfaces/delegator/IFullRestakeDelegator.sol";
import {INetworkRestakeDelegator} from
    "@symbiotic/core/interfaces/delegator/INetworkRestakeDelegator.sol";
import {INetworkMiddlewareService} from
    "@symbiotic/core/interfaces/service/INetworkMiddlewareService.sol";
import {IBaseSlasher} from "@symbiotic/core/interfaces/slasher/IBaseSlasher.sol";
import {ISlasher} from "@symbiotic/core/interfaces/slasher/ISlasher.sol";
import {IVetoSlasher} from "@symbiotic/core/interfaces/slasher/IVetoSlasher.sol";
import {IVault} from "@symbiotic/core/interfaces/vault/IVault.sol";

contract Deploy is Script {
    address public constant MELLOW_LIDO_MULTISIG = address(0);
    address public constant ROCK_X_CURATOR_MULTISIG = address(0);

    address public constant MIGRATOR_ADMIN = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    uint256 public constant MIGRATOR_DELAY = 6 hours;

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

    bytes32 public constant SINGLETON_SALT = bytes32(uint256(6641391));
    bytes32 public constant MIGRATOR_SALT = bytes32(uint256(16415115));
    bytes32 public constant ETH_WRAPPER_SALT = bytes32(uint256(145570050));

    function _deployCoreContracts() internal {
        MellowVaultCompat singleton =
            new MellowVaultCompat{salt: SINGLETON_SALT}("MellowSymbioticVault", 1);

        Migrator migrator =
            new Migrator{salt: MIGRATOR_SALT}(address(singleton), MIGRATOR_ADMIN, MIGRATOR_DELAY);

        EthWrapper ethWrapper = new EthWrapper{salt: ETH_WRAPPER_SALT}(WETH, WSTETH, STETH);
    }

    function _createArray(address curator) internal pure returns (address[] memory a) {
        a = new address[](1);
        a[0] = curator;
    }

    function _deploySymbioticVaults() internal {
        IVaultConfigurator vaultConfigurator =
            IVaultConfigurator(0x29300b1d3150B4E2b12fE80BE72f365E200441EC);

        // IRouterBurnerFactory routerBurnerFactory = IRouterBurnerFactory(0x99F2B89fB3C363fBafD8d826E5AA77b28bAB70a0);

        uint256 vetoSlasherIndex = 0;
        bytes memory vetoSlaherDefaultParams;

        // rockX
        {
            address routerBurner = address(0);
            (address vault, address delegator, address slasher) = vaultConfigurator.create(
                IVaultConfigurator.InitParams({
                    version: 0,
                    owner: MELLOW_LIDO_MULTISIG,
                    vaultParams: abi.encode(
                        IVault.InitParams({
                            collateral: WSTETH,
                            burner: routerBurner,
                            epochDuration: 7 days,
                            depositWhitelist: true,
                            isDepositLimit: false,
                            depositLimit: 0,
                            defaultAdminRoleHolder: MELLOW_LIDO_MULTISIG,
                            depositWhitelistSetRoleHolder: MELLOW_LIDO_MULTISIG,
                            depositorWhitelistRoleHolder: MELLOW_LIDO_MULTISIG,
                            isDepositLimitSetRoleHolder: MELLOW_LIDO_MULTISIG,
                            depositLimitSetRoleHolder: MELLOW_LIDO_MULTISIG
                        })
                    ),
                    delegatorIndex: 0,
                    delegatorParams: abi.encode(
                        INetworkRestakeDelegator.InitParams({
                            baseParams: IBaseDelegator.BaseParams({
                                defaultAdminRoleHolder: MELLOW_LIDO_MULTISIG,
                                hook: address(0),
                                hookSetRoleHolder: MELLOW_LIDO_MULTISIG
                            }),
                            networkLimitSetRoleHolders: _createArray(ROCK_X_CURATOR_MULTISIG),
                            operatorNetworkSharesSetRoleHolders: _createArray(ROCK_X_CURATOR_MULTISIG)
                        })
                    ),
                    withSlasher: true,
                    slasherIndex: 0,
                    slasherParams: abi.encode(
                        IVetoSlasher.InitParams({
                            baseParams: IBaseSlasher.BaseParams({isBurnerHook: true}),
                            vetoDuration: 6 days,
                            resolverSetEpochsDelay: 3
                        })
                    )
                })
            );

            console2.log("rockX deployment:");
            console2.log("curator multisig", ROCK_X_CURATOR_MULTISIG);
            console2.log("symbiotic vault", vault);
            console2.log("delegator", delegator);
            console2.log("slasher", slasher);
            console2.log("router burner", routerBurner);
        }

        // rstETH

        // amphorETH

        // steakLRT

        // re7ETH
    }

    function run() external {
        vm.startBroadcast(uint256(bytes32(vm.envBytes("MAINNET_DEPLOYER"))));

        _deployCoreContracts();
        _deploySymbioticVaults();

        vm.stopBroadcast();

        revert("ok");
    }
}
