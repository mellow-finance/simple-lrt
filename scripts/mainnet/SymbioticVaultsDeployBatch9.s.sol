// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

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
    address public constant VAULT_ADMIN_MULTISIG = 0xa62243c7a36e74d8280781242a3B0e019ce74E64;
    address public constant VAULT_PROXY_ADMIN_MULTISIG = 0xC7e8b00a61adB658c49D2d8a377FC44572e9ECb5;

    uint32 public constant EPOCH_DURATION = 7 days;
    uint32 public constant VETO_DURATION = 3 days;
    uint32 public constant BURNER_DELAY = 15 days;
    uint32 public constant VAULT_VERSION = 1;
    uint256 public constant RESOLVER_SET_EPOCHS_DELAY = 3;

    address public constant VAULT_CONFIGURATOR = 0x29300b1d3150B4E2b12fE80BE72f365E200441EC;
    address public constant BURNER_ROUTER_FACTORY = 0x99F2B89fB3C363fBafD8d826E5AA77b28bAB70a0;
    address public constant DEFAULT_BURNER = address(0xdead);

    uint32 public constant VETO_SLASHER_INDEX = 1;
    uint32 public constant NETWORK_RESTAKE_DELEGATOR_INDEX = 0;

    address public constant LISK_WSTETH_OFT_ADAPTER = 0x7f98073e7234B7c7F9d0223168dBCd95feAfba58;
    address public constant LISK_MBTC_OFT_ADAPTER = 0xdFCaB55563345Ed11616A377a6ba6189F2B57d4c;
    address public constant LISK_LSK_OFT_ADAPTER = 0x20347ece0df3B4B413eE656B9FfCc0562285be71;
    uint256 public constant N = 3;
    address public constant DEPLOYER = 0x188858AC61a74350116d1CB6958fBc509FD6afA1;

    address public constant RE7_MULTISIG = 0xE86399fE6d7007FdEcb08A2ee1434Ee677a04433;

    function _createArray(address curator) internal pure returns (address[] memory a) {
        a = new address[](1);
        a[0] = curator;
    }

    function _getNetworkReceivers()
        internal
        pure
        returns (IBurnerRouter.NetworkReceiver[] memory networkReceivers)
    {
        networkReceivers = new IBurnerRouter.NetworkReceiver[](1);
        networkReceivers[0] = IBurnerRouter.NetworkReceiver({
            network: 0x9101eda106A443A0fA82375936D0D1680D5a64F5,
            receiver: 0xD5881f91270550B8850127f05BD6C8C203B3D33f
        });
    }

    function _deploySymbioticVaults() internal {
        IVaultConfigurator vaultConfigurator = IVaultConfigurator(VAULT_CONFIGURATOR);
        IBurnerRouterFactory burnerRouterFactory = IBurnerRouterFactory(BURNER_ROUTER_FACTORY);

        address[N] memory curators = [RE7_MULTISIG, RE7_MULTISIG, RE7_MULTISIG];
        string[N] memory names = ["Lisk WSTETH Vault", "Lisk MBTC Vault", "Lisk LSK Vault"];
        address[N] memory assets =
            [LISK_WSTETH_OFT_ADAPTER, LISK_MBTC_OFT_ADAPTER, LISK_LSK_OFT_ADAPTER];

        for (uint256 i = 0; i < N; i++) {
            address asset = assets[i];
            address curator = curators[i];
            address burner = burnerRouterFactory.create(
                IBurnerRouter.InitParams({
                    owner: VAULT_ADMIN_MULTISIG,
                    collateral: asset,
                    delay: BURNER_DELAY,
                    globalReceiver: DEFAULT_BURNER,
                    networkReceivers: _getNetworkReceivers(),
                    operatorNetworkReceivers: new IBurnerRouter.OperatorNetworkReceiver[](0)
                })
            );
            (address vault, address delegator, address slasher) = vaultConfigurator.create(
                IVaultConfigurator.InitParams({
                    version: VAULT_VERSION,
                    owner: VAULT_PROXY_ADMIN_MULTISIG,
                    vaultParams: abi.encode(
                        IVault.InitParams({
                            collateral: asset,
                            burner: burner,
                            epochDuration: EPOCH_DURATION,
                            depositWhitelist: true,
                            isDepositLimit: true,
                            depositLimit: 0,
                            defaultAdminRoleHolder: VAULT_ADMIN_MULTISIG,
                            depositWhitelistSetRoleHolder: VAULT_ADMIN_MULTISIG,
                            depositorWhitelistRoleHolder: DEPLOYER,
                            isDepositLimitSetRoleHolder: VAULT_ADMIN_MULTISIG,
                            depositLimitSetRoleHolder: curator
                        })
                    ),
                    delegatorIndex: NETWORK_RESTAKE_DELEGATOR_INDEX,
                    delegatorParams: abi.encode(
                        INetworkRestakeDelegator.InitParams({
                            baseParams: IBaseDelegator.BaseParams({
                                defaultAdminRoleHolder: VAULT_ADMIN_MULTISIG,
                                hook: address(0),
                                hookSetRoleHolder: VAULT_ADMIN_MULTISIG
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
        uint256 deployerPk = uint256(bytes32(vm.envBytes("MAINNET_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        require(deployer == DEPLOYER, "not authorized");
        vm.startBroadcast(deployerPk);

        _deploySymbioticVaults();

        vm.stopBroadcast();
        // revert("success");
    }
}
