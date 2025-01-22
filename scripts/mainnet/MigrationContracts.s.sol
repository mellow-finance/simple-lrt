// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {EthWrapper} from "../../src/EthWrapper.sol";
import {MellowSymbioticVault} from "../../src/MellowSymbioticVault.sol";

import {MellowSymbioticVaultFactory} from "../../src/MellowSymbioticVaultFactory.sol";
import {MellowVaultCompat} from "../../src/MellowVaultCompat.sol";
import {Migrator} from "../../src/Migrator.sol";

import {IBurnerRouter} from "@symbiotic/burners/interfaces/router/IBurnerRouter.sol";
import {IBurnerRouterFactory} from "@symbiotic/burners/interfaces/router/IBurnerRouterFactory.sol";
import {IVaultConfigurator} from "@symbiotic/core/interfaces/IVaultConfigurator.sol";
import {IBaseDelegator} from "@symbiotic/core/interfaces/delegator/IBaseDelegator.sol";
import {IFullRestakeDelegator} from "@symbiotic/core/interfaces/delegator/IFullRestakeDelegator.sol";
import {INetworkRestakeDelegator} from
    "@symbiotic/core/interfaces/delegator/INetworkRestakeDelegator.sol";
import {IBaseSlasher} from "@symbiotic/core/interfaces/slasher/IBaseSlasher.sol";
import {ISlasher} from "@symbiotic/core/interfaces/slasher/ISlasher.sol";
import {IVetoSlasher} from "@symbiotic/core/interfaces/slasher/IVetoSlasher.sol";
import {IVault} from "@symbiotic/core/interfaces/vault/IVault.sol";

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

contract Deploy is Script {
    address public constant MELLOW_LIDO_MULTISIG = 0x9437B2a8cF3b69D782a61f9814baAbc172f72003;

    address public constant ROCK_X_CURATOR_MULTISIG = 0x9275cC6de34471f4a669e9dc0F90994Ad6702DA9;
    address public constant P2P_CURATOR_MULTISIG = 0x4a3c7F2470Aa00ebE6aE7cB1fAF95964b9de1eF4;
    address public constant AMPHOR_CURATOR_MULTISIG = 0xA1E38210B06A05882a7e7Bfe167Cd67F07FA234A;
    address public constant RENZO_CURATOR_MULTISIG = 0x6e5CaD73D00Bc8340f38afb61Fc5E34f7193F599;
    address public constant STEAKHOUSE_CURATOR_MULTISIG = 0x2E93913A796a6C6b2bB76F41690E78a2E206Be54;
    address public constant RE7_CURATOR_MULTISIG = 0xE86399fE6d7007FdEcb08A2ee1434Ee677a04433;

    address public constant MIGRATOR_ADMIN = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    uint256 public constant MIGRATOR_DELAY = 6 hours;

    uint32 public constant EPOCH_DURATION = 7 days;
    uint32 public constant VETO_DURATION = 5 days;
    uint32 public constant BURNER_DELAY = 1 hours; // reasoning: to make it possible to change values in the BurnerRouter contract right after deployment (JIC)
    uint32 public constant VAULT_VERSION = 1;

    uint32 public constant VETO_SLASHER_INDEX = 1;

    uint32 public constant NETWORK_RESTAKE_DELEGATOR_INDEX = 0;
    uint32 public constant FULL_RESTAKE_DELEGATOR_INDEX = 1;

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

    bytes32 public constant MELLOW_VAULT_COMPAT_SINGLETON_SALT = bytes32(uint256(31925074));
    bytes32 public constant MIGRATOR_SALT = bytes32(uint256(1037221950));
    bytes32 public constant ETH_WRAPPER_SALT = bytes32(uint256(2035485209));
    bytes32 public constant MELLOW_SYMBIOTIC_VAULT_SINGLETON_SALT = bytes32(uint256(130700478));
    bytes32 public constant MELLOW_SYMBIOTIC_VAULT_FACTORY_SALT = bytes32(uint256(655157589)); // NOTE: TO BE SET

    function _deployCoreContracts() internal {
        MellowVaultCompat mellowVaultCompatSingleton = new MellowVaultCompat{
            salt: MELLOW_VAULT_COMPAT_SINGLETON_SALT
        }("MellowSymbioticVault", 1);

        Migrator migrator = new Migrator{salt: MIGRATOR_SALT}(
            address(mellowVaultCompatSingleton), MIGRATOR_ADMIN, MIGRATOR_DELAY
        );

        EthWrapper ethWrapper = new EthWrapper{salt: ETH_WRAPPER_SALT}(WETH, WSTETH, STETH);

        MellowSymbioticVault mellowSymbioticVaultSingleton = new MellowSymbioticVault{
            salt: MELLOW_SYMBIOTIC_VAULT_SINGLETON_SALT
        }("MellowSymbioticVault", 1);
        MellowSymbioticVaultFactory mellowSymbioticVaultFactory = new MellowSymbioticVaultFactory{
            salt: MELLOW_SYMBIOTIC_VAULT_FACTORY_SALT
        }(address(mellowSymbioticVaultSingleton));

        console2.log("MellowVaultCompat", address(mellowVaultCompatSingleton));
        console2.log("Migrator", address(migrator));
        console2.log("EthWrapper", address(ethWrapper));
        console2.log("MellowSymbioticVault", address(mellowSymbioticVaultSingleton));
        console2.log("MellowSymbioticVaultFactory", address(mellowSymbioticVaultFactory));
    }

    function _createArray(address curator) internal pure returns (address[] memory a) {
        a = new address[](1);
        a[0] = curator;
    }

    function _deploySymbioticVaults() internal {
        IVaultConfigurator vaultConfigurator =
            IVaultConfigurator(0x29300b1d3150B4E2b12fE80BE72f365E200441EC);

        IBurnerRouterFactory burnerRouterFactory =
            IBurnerRouterFactory(0x99F2B89fB3C363fBafD8d826E5AA77b28bAB70a0);

        IVault.InitParams memory defaultVaultParams = IVault.InitParams({
            collateral: WSTETH,
            burner: address(0), // NOTE: TO BE SET
            epochDuration: EPOCH_DURATION,
            depositWhitelist: true,
            isDepositLimit: false,
            depositLimit: 0,
            defaultAdminRoleHolder: MELLOW_LIDO_MULTISIG,
            depositWhitelistSetRoleHolder: MELLOW_LIDO_MULTISIG,
            depositorWhitelistRoleHolder: MELLOW_LIDO_MULTISIG,
            isDepositLimitSetRoleHolder: MELLOW_LIDO_MULTISIG,
            depositLimitSetRoleHolder: MELLOW_LIDO_MULTISIG
        });

        IBurnerRouter.InitParams memory defaultBurnerParams = IBurnerRouter.InitParams({
            owner: MELLOW_LIDO_MULTISIG,
            collateral: WSTETH,
            delay: BURNER_DELAY,
            globalReceiver: address(0), // NOTE: TO BE SET
            networkReceivers: new IBurnerRouter.NetworkReceiver[](0),
            operatorNetworkReceivers: new IBurnerRouter.OperatorNetworkReceiver[](0)
        });

        bytes memory defaultSlasherParams = abi.encode(
            IVetoSlasher.InitParams({
                baseParams: IBaseSlasher.BaseParams({isBurnerHook: true}),
                vetoDuration: 6 days,
                resolverSetEpochsDelay: 3
            })
        );

        INetworkRestakeDelegator.InitParams memory defaultNetworkRestakeDelegatorParams =
        INetworkRestakeDelegator.InitParams({
            baseParams: IBaseDelegator.BaseParams({
                defaultAdminRoleHolder: MELLOW_LIDO_MULTISIG,
                hook: address(0),
                hookSetRoleHolder: MELLOW_LIDO_MULTISIG
            }),
            networkLimitSetRoleHolders: new address[](0), // NOTE: TO BE SET
            operatorNetworkSharesSetRoleHolders: new address[](0) // NOTE: TO BE SET
        });

        IFullRestakeDelegator.InitParams memory defaultFullRestakeDelegatorParams =
        IFullRestakeDelegator.InitParams({
            baseParams: IBaseDelegator.BaseParams({
                defaultAdminRoleHolder: MELLOW_LIDO_MULTISIG,
                hook: address(0),
                hookSetRoleHolder: MELLOW_LIDO_MULTISIG
            }),
            networkLimitSetRoleHolders: new address[](0), // NOTE: TO BE SET
            operatorNetworkLimitSetRoleHolders: new address[](0) // NOTE: TO BE SET
        });

        // rockX
        {
            defaultBurnerParams.globalReceiver = ROCK_X_CURATOR_MULTISIG;
            address routerBurner = burnerRouterFactory.create(defaultBurnerParams);
            defaultVaultParams.burner = routerBurner;
            defaultNetworkRestakeDelegatorParams.networkLimitSetRoleHolders =
                _createArray(ROCK_X_CURATOR_MULTISIG);
            defaultNetworkRestakeDelegatorParams.operatorNetworkSharesSetRoleHolders =
                _createArray(ROCK_X_CURATOR_MULTISIG);
            (address vault, address delegator, address slasher) = vaultConfigurator.create(
                IVaultConfigurator.InitParams({
                    version: VAULT_VERSION,
                    owner: MELLOW_LIDO_MULTISIG,
                    vaultParams: abi.encode(defaultVaultParams),
                    delegatorIndex: NETWORK_RESTAKE_DELEGATOR_INDEX,
                    delegatorParams: abi.encode(defaultNetworkRestakeDelegatorParams),
                    withSlasher: true,
                    slasherIndex: VETO_SLASHER_INDEX,
                    slasherParams: defaultSlasherParams
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
        {
            defaultBurnerParams.globalReceiver = P2P_CURATOR_MULTISIG;
            address routerBurner = burnerRouterFactory.create(defaultBurnerParams);
            defaultVaultParams.burner = routerBurner;
            defaultNetworkRestakeDelegatorParams.networkLimitSetRoleHolders =
                _createArray(P2P_CURATOR_MULTISIG);
            defaultNetworkRestakeDelegatorParams.operatorNetworkSharesSetRoleHolders =
                _createArray(P2P_CURATOR_MULTISIG);
            (address vault, address delegator, address slasher) = vaultConfigurator.create(
                IVaultConfigurator.InitParams({
                    version: VAULT_VERSION,
                    owner: MELLOW_LIDO_MULTISIG,
                    vaultParams: abi.encode(defaultVaultParams),
                    delegatorIndex: NETWORK_RESTAKE_DELEGATOR_INDEX,
                    delegatorParams: abi.encode(defaultNetworkRestakeDelegatorParams),
                    withSlasher: true,
                    slasherIndex: VETO_SLASHER_INDEX,
                    slasherParams: defaultSlasherParams
                })
            );

            console2.log("p2p deployment:");
            console2.log("curator multisig", P2P_CURATOR_MULTISIG);
            console2.log("symbiotic vault", vault);
            console2.log("delegator", delegator);
            console2.log("slasher", slasher);
            console2.log("router burner", routerBurner);
        }

        // amphorETH
        {
            defaultBurnerParams.globalReceiver = AMPHOR_CURATOR_MULTISIG;
            address routerBurner = burnerRouterFactory.create(defaultBurnerParams);
            defaultVaultParams.burner = routerBurner;
            defaultFullRestakeDelegatorParams.networkLimitSetRoleHolders =
                _createArray(AMPHOR_CURATOR_MULTISIG);
            defaultFullRestakeDelegatorParams.operatorNetworkLimitSetRoleHolders =
                _createArray(AMPHOR_CURATOR_MULTISIG);
            (address vault, address delegator, address slasher) = vaultConfigurator.create(
                IVaultConfigurator.InitParams({
                    version: VAULT_VERSION,
                    owner: MELLOW_LIDO_MULTISIG,
                    vaultParams: abi.encode(defaultVaultParams),
                    delegatorIndex: FULL_RESTAKE_DELEGATOR_INDEX,
                    delegatorParams: abi.encode(defaultFullRestakeDelegatorParams),
                    withSlasher: true,
                    slasherIndex: VETO_SLASHER_INDEX,
                    slasherParams: defaultSlasherParams
                })
            );

            console2.log("amphor deployment:");
            console2.log("curator multisig", AMPHOR_CURATOR_MULTISIG);
            console2.log("symbiotic vault", vault);
            console2.log("delegator", delegator);
            console2.log("slasher", slasher);
            console2.log("router burner", routerBurner);
        }

        // renzo
        {
            defaultBurnerParams.globalReceiver = RENZO_CURATOR_MULTISIG;
            address routerBurner = burnerRouterFactory.create(defaultBurnerParams);
            defaultVaultParams.burner = routerBurner;
            defaultNetworkRestakeDelegatorParams.networkLimitSetRoleHolders =
                _createArray(RENZO_CURATOR_MULTISIG);
            defaultNetworkRestakeDelegatorParams.operatorNetworkSharesSetRoleHolders =
                _createArray(RENZO_CURATOR_MULTISIG);
            (address vault, address delegator, address slasher) = vaultConfigurator.create(
                IVaultConfigurator.InitParams({
                    version: VAULT_VERSION,
                    owner: MELLOW_LIDO_MULTISIG,
                    vaultParams: abi.encode(defaultVaultParams),
                    delegatorIndex: NETWORK_RESTAKE_DELEGATOR_INDEX,
                    delegatorParams: abi.encode(defaultNetworkRestakeDelegatorParams),
                    withSlasher: true,
                    slasherIndex: VETO_SLASHER_INDEX,
                    slasherParams: defaultSlasherParams
                })
            );

            console2.log("p2p deployment:");
            console2.log("curator multisig", RENZO_CURATOR_MULTISIG);
            console2.log("symbiotic vault", vault);
            console2.log("delegator", delegator);
            console2.log("slasher", slasher);
            console2.log("router burner", routerBurner);
        }

        // steakLRT
        {
            defaultBurnerParams.globalReceiver = STEAKHOUSE_CURATOR_MULTISIG;
            address routerBurner = burnerRouterFactory.create(defaultBurnerParams);
            defaultVaultParams.burner = routerBurner;
            defaultNetworkRestakeDelegatorParams.networkLimitSetRoleHolders =
                _createArray(STEAKHOUSE_CURATOR_MULTISIG);
            defaultNetworkRestakeDelegatorParams.operatorNetworkSharesSetRoleHolders =
                _createArray(STEAKHOUSE_CURATOR_MULTISIG);
            (address vault, address delegator, address slasher) = vaultConfigurator.create(
                IVaultConfigurator.InitParams({
                    version: VAULT_VERSION,
                    owner: MELLOW_LIDO_MULTISIG,
                    vaultParams: abi.encode(defaultVaultParams),
                    delegatorIndex: NETWORK_RESTAKE_DELEGATOR_INDEX,
                    delegatorParams: abi.encode(defaultNetworkRestakeDelegatorParams),
                    withSlasher: true,
                    slasherIndex: VETO_SLASHER_INDEX,
                    slasherParams: defaultSlasherParams
                })
            );

            console2.log("steakhouse deployment:");
            console2.log("curator multisig", STEAKHOUSE_CURATOR_MULTISIG);
            console2.log("symbiotic vault", vault);
            console2.log("delegator", delegator);
            console2.log("slasher", slasher);
            console2.log("router burner", routerBurner);
        }

        // re7ETH
        {
            defaultBurnerParams.globalReceiver = RE7_CURATOR_MULTISIG;
            address routerBurner = burnerRouterFactory.create(defaultBurnerParams);
            defaultVaultParams.burner = routerBurner;
            defaultNetworkRestakeDelegatorParams.networkLimitSetRoleHolders =
                _createArray(RE7_CURATOR_MULTISIG);
            defaultNetworkRestakeDelegatorParams.operatorNetworkSharesSetRoleHolders =
                _createArray(RE7_CURATOR_MULTISIG);
            (address vault, address delegator, address slasher) = vaultConfigurator.create(
                IVaultConfigurator.InitParams({
                    version: VAULT_VERSION,
                    owner: MELLOW_LIDO_MULTISIG,
                    vaultParams: abi.encode(defaultVaultParams),
                    delegatorIndex: NETWORK_RESTAKE_DELEGATOR_INDEX,
                    delegatorParams: abi.encode(defaultNetworkRestakeDelegatorParams),
                    withSlasher: true,
                    slasherIndex: VETO_SLASHER_INDEX,
                    slasherParams: defaultSlasherParams
                })
            );

            console2.log("re7 deployment:");
            console2.log("curator multisig", RE7_CURATOR_MULTISIG);
            console2.log("symbiotic vault", vault);
            console2.log("delegator", delegator);
            console2.log("slasher", slasher);
            console2.log("router burner", routerBurner);
        }
    }

    function run() external {
        vm.startBroadcast(uint256(bytes32(vm.envBytes("MAINNET_DEPLOYER"))));

        _deployCoreContracts();
        _deploySymbioticVaults();

        vm.stopBroadcast();

        revert("WIP!!!");
    }
}
