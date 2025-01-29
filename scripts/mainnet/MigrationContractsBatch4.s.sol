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
    address public constant BTC_VAULT_PROXY_ADMIN = 0x002910769444bd0D715CC4c6f2A90D92C5e6695e;
    address public constant BTC_VAULT_ADMIN = 0x6aD30f260c5081Cae68962e2f1730a3727987Deb;

    address public constant RE7BTC_CURATOR_MULTISIG = 0xE86399fE6d7007FdEcb08A2ee1434Ee677a04433;
    address public constant AMPHOR_CURATOR_MULTISIG = 0xA1E38210B06A05882a7e7Bfe167Cd67F07FA234A;

    uint32 public constant EPOCH_DURATION = 7 days;
    uint32 public constant VETO_DURATION = 3 days;
    uint32 public constant BURNER_DELAY = 0;
    uint32 public constant VAULT_VERSION = 1;

    address public constant VAULT_CONFIGURATOR = 0x29300b1d3150B4E2b12fE80BE72f365E200441EC;
    address public constant BURNER_ROUTER_FACTORY = 0x99F2B89fB3C363fBafD8d826E5AA77b28bAB70a0;

    address public constant DEAD_BURNER = address(0xdead);

    uint32 public constant VETO_SLASHER_INDEX = 1;
    uint32 public constant NETWORK_RESTAKE_DELEGATOR_INDEX = 0;

    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant TBTC = 0x18084fbA666a33d37592fA2633fD49a74DD93a88;

    function _createArray(address curator) internal pure returns (address[] memory a) {
        a = new address[](1);
        a[0] = curator;
    }

    function _deploySymbioticVaults() internal {
        IVaultConfigurator vaultConfigurator = IVaultConfigurator(VAULT_CONFIGURATOR);
        IBurnerRouterFactory burnerRouterFactory = IBurnerRouterFactory(BURNER_ROUTER_FACTORY);
        address[3] memory collaterals = [WBTC, WBTC, TBTC];
        string[3] memory names = ["Re7rwBTC", "amphrBTC", "Re7rtBTC"];
        address[3] memory curators =
            [RE7BTC_CURATOR_MULTISIG, AMPHOR_CURATOR_MULTISIG, RE7BTC_CURATOR_MULTISIG];
        for (uint256 i = 0; i < 3; i++) {
            address burner = burnerRouterFactory.create(
                IBurnerRouter.InitParams({
                    owner: BTC_VAULT_ADMIN,
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
                    owner: BTC_VAULT_PROXY_ADMIN,
                    vaultParams: abi.encode(
                        IVault.InitParams({
                            collateral: collaterals[i],
                            burner: burner,
                            epochDuration: EPOCH_DURATION,
                            depositWhitelist: true,
                            isDepositLimit: true,
                            depositLimit: 0,
                            defaultAdminRoleHolder: BTC_VAULT_ADMIN,
                            depositWhitelistSetRoleHolder: address(0),
                            depositorWhitelistRoleHolder: address(0),
                            isDepositLimitSetRoleHolder: address(0),
                            depositLimitSetRoleHolder: curators[i]
                        })
                    ),
                    delegatorIndex: NETWORK_RESTAKE_DELEGATOR_INDEX,
                    delegatorParams: abi.encode(
                        INetworkRestakeDelegator.InitParams({
                            baseParams: IBaseDelegator.BaseParams({
                                defaultAdminRoleHolder: BTC_VAULT_ADMIN,
                                hook: address(0),
                                hookSetRoleHolder: address(0)
                            }),
                            networkLimitSetRoleHolders: _createArray(curators[i]),
                            operatorNetworkSharesSetRoleHolders: _createArray(curators[i])
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
            console2.log("curator multisig", curators[i]);
            console2.log("symbiotic vault", vault);
            console2.log("delegator", delegator);
            console2.log("slasher", slasher);
            console2.log("burner", burner);
        }
    }

    function run() external {
        vm.startBroadcast(uint256(bytes32(vm.envBytes("MAINNET_DEPLOYER"))));
        Migrator migrator =
            new Migrator(MELLOW_VAULT_COMPAT_SINGLETON, BTC_VAULT_PROXY_ADMIN, 1 hours);
        console2.log("Migrator (BTC):", address(migrator));
        _deploySymbioticVaults();
        vm.stopBroadcast();
        revert("done");
    }
}
