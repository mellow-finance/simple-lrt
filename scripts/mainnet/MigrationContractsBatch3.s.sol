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
import {INetworkRestakeDelegator} from
    "@symbiotic/core/interfaces/delegator/INetworkRestakeDelegator.sol";
import {IBaseSlasher} from "@symbiotic/core/interfaces/slasher/IBaseSlasher.sol";
import {IVetoSlasher} from "@symbiotic/core/interfaces/slasher/IVetoSlasher.sol";
import {IVault} from "@symbiotic/core/interfaces/vault/IVault.sol";

contract Deploy is Script {
    address public constant MELLOW_VAULT_COMPAT_SINGLETON =
        0x09bBa67C316e59840699124a8DC0bBDa6A2A9d59;
    address public constant ETHENA_VAULT_PROXY_ADMIN = 0x27a907d1F809E8c03d806Dc31c8E0C545A3187fC;
    address public constant ETHENA_VAULT_ADMIN = 0xa5136542ECF3dCAFbb3bd213Cd7024B4741dBDE6;

    address public constant ETHENA_CURATOR_MULTISIG = 0x9389477cf0a0C13ad0eE54f35587C9d7d121B231;

    uint32 public constant EPOCH_DURATION = 7 days;
    uint32 public constant VETO_DURATION = 3 days;
    uint32 public constant BURNER_DELAY = 0;
    uint32 public constant VAULT_VERSION = 1;

    address public constant VAULT_CONFIGURATOR = 0x29300b1d3150B4E2b12fE80BE72f365E200441EC;
    address public constant BURNER_ROUTER_FACTORY = 0x99F2B89fB3C363fBafD8d826E5AA77b28bAB70a0;

    address public constant DEAD_BURNER = address(0xdead);

    uint32 public constant VETO_SLASHER_INDEX = 1;
    uint32 public constant NETWORK_RESTAKE_DELEGATOR_INDEX = 0;

    address public constant SUSDE = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address public constant ENA = 0x57e114B691Db790C35207b2e685D4A43181e6061;

    function _createArray(address curator) internal pure returns (address[] memory a) {
        a = new address[](1);
        a[0] = curator;
    }

    function _deploySymbioticVaults() internal {
        IVaultConfigurator vaultConfigurator = IVaultConfigurator(VAULT_CONFIGURATOR);
        IBurnerRouterFactory burnerRouterFactory = IBurnerRouterFactory(BURNER_ROUTER_FACTORY);
        address[2] memory collaterals = [SUSDE, ENA];
        string[2] memory names = ["rsUSDe", "rsENA"];
        for (uint256 i = 0; i < 2; i++) {
            address burner = burnerRouterFactory.create(
                IBurnerRouter.InitParams({
                    owner: ETHENA_VAULT_ADMIN,
                    collateral: collaterals[i],
                    delay: BURNER_DELAY,
                    globalReceiver: DEAD_BURNER,
                    networkReceivers: new IBurnerRouter.NetworkReceiver[](0),
                    operatorNetworkReceivers: new IBurnerRouter.OperatorNetworkReceiver[](0)
                })
            );
            (address vault, address delegator, address slasher) = vaultConfigurator.create(
                IVaultConfigurator.InitParams({
                    version: VAULT_VERSION,
                    owner: ETHENA_VAULT_PROXY_ADMIN,
                    vaultParams: abi.encode(
                        IVault.InitParams({
                            collateral: collaterals[i],
                            burner: burner,
                            epochDuration: EPOCH_DURATION,
                            depositWhitelist: true,
                            isDepositLimit: true,
                            depositLimit: 0,
                            defaultAdminRoleHolder: ETHENA_VAULT_ADMIN,
                            depositWhitelistSetRoleHolder: ETHENA_VAULT_ADMIN,
                            depositorWhitelistRoleHolder: ETHENA_VAULT_ADMIN,
                            isDepositLimitSetRoleHolder: ETHENA_VAULT_ADMIN,
                            depositLimitSetRoleHolder: ETHENA_CURATOR_MULTISIG
                        })
                    ),
                    delegatorIndex: NETWORK_RESTAKE_DELEGATOR_INDEX,
                    delegatorParams: abi.encode(
                        INetworkRestakeDelegator.InitParams({
                            baseParams: IBaseDelegator.BaseParams({
                                defaultAdminRoleHolder: ETHENA_VAULT_ADMIN,
                                hook: address(0),
                                hookSetRoleHolder: ETHENA_VAULT_ADMIN
                            }),
                            networkLimitSetRoleHolders: _createArray(ETHENA_CURATOR_MULTISIG),
                            operatorNetworkSharesSetRoleHolders: _createArray(ETHENA_CURATOR_MULTISIG)
                        })
                    ),
                    withSlasher: true,
                    slasherIndex: VETO_SLASHER_INDEX,
                    slasherParams: abi.encode(
                        IVetoSlasher.InitParams({
                            baseParams: IBaseSlasher.BaseParams({isBurnerHook: true}),
                            vetoDuration: VETO_DURATION,
                            resolverSetEpochsDelay: 3
                        })
                    )
                })
            );

            console2.log(names[i], "deployment:");
            console2.log("curator multisig", ETHENA_CURATOR_MULTISIG);
            console2.log("symbiotic vault", vault);
            console2.log("delegator", delegator);
            console2.log("slasher", slasher);
            console2.log("burner", burner);
        }
    }

    function run() external {
        vm.startBroadcast(uint256(bytes32(vm.envBytes("MAINNET_DEPLOYER"))));
        _deploySymbioticVaults();
        vm.stopBroadcast();
        // revert("done");
    }
}
