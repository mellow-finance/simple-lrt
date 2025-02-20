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

interface ISafe {
    function getOwners() external view returns (address[] memory);
}

contract Deploy is Script {
    address public constant VAULT_ADMIN_MULTISIG = 0x9437B2a8cF3b69D782a61f9814baAbc172f72003;
    address public constant VAULT_PROXY_ADMIN_MULTISIG = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;

    address public constant MEV_CURATOR_MULTISIG = 0xA1E38210B06A05882a7e7Bfe167Cd67F07FA234A;

    uint32 public constant EPOCH_DURATION = 7 days;
    uint32 public constant VETO_DURATION = 3 days;
    uint32 public constant BURNER_DELAY = 1 seconds;
    uint32 public constant VAULT_VERSION = 1;
    uint256 public constant RESOLVER_SET_EPOCHS_DELAY = 3;

    address public constant VAULT_CONFIGURATOR = 0x29300b1d3150B4E2b12fE80BE72f365E200441EC;
    address public constant BURNER_ROUTER_FACTORY = 0x99F2B89fB3C363fBafD8d826E5AA77b28bAB70a0;
    address public constant WSTETH_BURNER = 0xdCaC890b14121FD5D925E2589017Be68C2B5B324;

    uint32 public constant VETO_SLASHER_INDEX = 1;
    uint32 public constant NETWORK_RESTAKE_DELEGATOR_INDEX = 0;

    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    function _createArray(address curator) internal pure returns (address[] memory a) {
        a = new address[](1);
        a[0] = curator;
    }

    function _deploySymbioticVaults() internal {
        IVaultConfigurator vaultConfigurator = IVaultConfigurator(VAULT_CONFIGURATOR);
        IBurnerRouterFactory burnerRouterFactory = IBurnerRouterFactory(BURNER_ROUTER_FACTORY);
        address[4] memory curators =
            [MEV_CURATOR_MULTISIG, MEV_CURATOR_MULTISIG, MEV_CURATOR_MULTISIG, MEV_CURATOR_MULTISIG];
        string[4] memory names = ["mevnoETH", "ALstETH", "mevkstETH", "mevblETH"];

        for (uint256 i = 0; i < 4; i++) {
            address curator = curators[i];
            address burner = burnerRouterFactory.create(
                IBurnerRouter.InitParams({
                    owner: VAULT_ADMIN_MULTISIG,
                    collateral: WSTETH,
                    delay: BURNER_DELAY,
                    globalReceiver: WSTETH_BURNER,
                    networkReceivers: new IBurnerRouter.NetworkReceiver[](0),
                    operatorNetworkReceivers: new IBurnerRouter.OperatorNetworkReceiver[](0)
                })
            );
            (address vault, address delegator, address slasher) = vaultConfigurator.create(
                IVaultConfigurator.InitParams({
                    version: VAULT_VERSION,
                    owner: VAULT_PROXY_ADMIN_MULTISIG,
                    vaultParams: abi.encode(
                        IVault.InitParams({
                            collateral: WSTETH,
                            burner: burner,
                            epochDuration: EPOCH_DURATION,
                            depositWhitelist: true,
                            isDepositLimit: true,
                            depositLimit: 0,
                            defaultAdminRoleHolder: MELLOW_LIDO_MULTISIG,
                            depositWhitelistSetRoleHolder: MELLOW_LIDO_MULTISIG,
                            depositorWhitelistRoleHolder: MELLOW_LIDO_MULTISIG,
                            isDepositLimitSetRoleHolder: MELLOW_LIDO_MULTISIG,
                            depositLimitSetRoleHolder: curator
                        })
                    ),
                    delegatorIndex: NETWORK_RESTAKE_DELEGATOR_INDEX,
                    delegatorParams: abi.encode(
                        INetworkRestakeDelegator.InitParams({
                            baseParams: IBaseDelegator.BaseParams({
                                defaultAdminRoleHolder: MELLOW_LIDO_MULTISIG,
                                hook: address(0),
                                hookSetRoleHolder: MELLOW_LIDO_MULTISIG
                            }),
                            networkLimitSetRoleHolders: _createArray(curator),
                            operatorNetworkSharesSetRoleHolders: _createArray(curator)
                        })
                    ),
                    withSlasher: true,
                    slasherIndex: VETO_SLASHER_INDEX,
                    slasherParams: abi.encode(
                        IVetoSlasher.InitParams({
                            baseParams: IBaseSlasher.BaseParams({isBurnerHook: true}),
                            vetoDuration: VETO_DURATION,
                            resolverSetEpochsDelay: RESOLVER_SET_EPOCHS_DELAY
                        })
                    )
                })
            );

            console2.log(names[i], "deployment:");
            console2.log("curator multisig", curator);
            console2.log("symbiotic vault", vault);
            console2.log("delegator", delegator);
            console2.log("slasher", slasher);
            console2.log("burner", burner);
        }
    }

    function run() external {
        vm.startBroadcast(uint256(bytes32(vm.envBytes("MAINNET_TEST_DEPLOYER"))));

        _deploySymbioticVaults();

        vm.stopBroadcast();
        revert("success");
    }
}
