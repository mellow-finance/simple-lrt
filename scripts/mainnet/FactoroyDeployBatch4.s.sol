// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {EthWrapper} from "../../src/EthWrapper.sol";
import {IMellowSymbioticVault, IWithdrawalQueue} from "../../src/MellowSymbioticVault.sol";
import {IMellowSymbioticVaultFactory} from "../../src/MellowSymbioticVaultFactory.sol";
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

interface IDefaultCollateralFactory {
    function create(address asset, uint256 initialLimit, address limitIncreaser)
        external
        returns (address);
}

contract Deploy is Script {
    uint32 public constant BURNER_DELAY = 15 days;
    uint32 public constant VAULT_VERSION = 1;

    address public constant VAULT_CONFIGURATOR = 0x29300b1d3150B4E2b12fE80BE72f365E200441EC;
    address public constant BURNER_ROUTER_FACTORY = 0x99F2B89fB3C363fBafD8d826E5AA77b28bAB70a0;

    uint32 public constant VETO_SLASHER_INDEX = 1;
    uint32 public constant NETWORK_RESTAKE_DELEGATOR_INDEX = 0;

    uint256 public constant RESOLVER_SET_EPOCHS_DELAY = 3;

    address public constant MELLOW_VAULT_FACTORY = 0x6EA5a344d116Db8949348648713760836D60fC5a;

    address public constant POND = 0x57B946008913B82E4dF85f501cbAeD910e58D26C;
    address public constant POND_CURATOR = 0xD1f59ba974E828dF68cB2592C16b967B637cB4e4;

    address public constant POND_VAULT_ADMIN = 0x1B7C5FfAe79b456fe1eEE47503253cbaC55bA287;
    address public constant POND_VAULT_PROXY_ADMIN = 0xa4E41e38FbBC176BB4f79aB9d4528CA8335950a6;

    address public constant DEFAULT_COLLATERAL_FACTORY = 0x1BC8FCFbE6Aa17e4A7610F51B888f34583D202Ec;

    uint48 public constant POND_VAULT_EPOCH_DURATION = 7 days;
    uint48 public constant POND_VETO_DURATION = 1 days;

    address public constant POND_GLOBAL_RECEIVER = address(0xdead);

    uint256 public constant POND_VAULT_LIMIT = 750e6 ether;

    string public constant POND_VAULT_NAME = "Marlin POND LRT";
    string public constant POND_VAULT_SYMBOL = "rsPOND";

    function _createArray(address curator) internal pure returns (address[] memory a) {
        a = new address[](1);
        a[0] = curator;
    }

    struct Stack {
        address asset;
        address globalReceiver;
        address vaultAdminMultisig;
        address vaultProxyAdminMultisig;
        address curator;
        uint48 vaultEpochDuration;
        uint48 vetoDuration;
    }

    function _deploySymbioticVault(Stack memory s) internal returns (address) {
        IBurnerRouterFactory burnerRouterFactory = IBurnerRouterFactory(BURNER_ROUTER_FACTORY);
        address burner = burnerRouterFactory.create(
            IBurnerRouter.InitParams({
                owner: s.vaultAdminMultisig,
                collateral: s.asset,
                delay: BURNER_DELAY,
                globalReceiver: s.globalReceiver,
                networkReceivers: new IBurnerRouter.NetworkReceiver[](0),
                operatorNetworkReceivers: new IBurnerRouter.OperatorNetworkReceiver[](0)
            })
        );
        IVaultConfigurator vaultConfigurator = IVaultConfigurator(VAULT_CONFIGURATOR);
        (address symbioticVault, address delegator, address slasher) = vaultConfigurator.create(
            IVaultConfigurator.InitParams({
                version: VAULT_VERSION,
                owner: s.vaultProxyAdminMultisig,
                vaultParams: abi.encode(
                    IVault.InitParams({
                        collateral: s.asset,
                        burner: burner,
                        epochDuration: s.vaultEpochDuration,
                        depositWhitelist: true,
                        isDepositLimit: true,
                        depositLimit: 0,
                        defaultAdminRoleHolder: s.vaultAdminMultisig,
                        depositWhitelistSetRoleHolder: s.vaultAdminMultisig,
                        depositorWhitelistRoleHolder: s.vaultAdminMultisig,
                        isDepositLimitSetRoleHolder: s.vaultAdminMultisig,
                        depositLimitSetRoleHolder: s.curator
                    })
                ),
                delegatorIndex: NETWORK_RESTAKE_DELEGATOR_INDEX,
                delegatorParams: abi.encode(
                    INetworkRestakeDelegator.InitParams({
                        baseParams: IBaseDelegator.BaseParams({
                            defaultAdminRoleHolder: s.vaultAdminMultisig,
                            hook: address(0),
                            hookSetRoleHolder: s.vaultAdminMultisig
                        }),
                        networkLimitSetRoleHolders: _createArray(s.curator),
                        operatorNetworkSharesSetRoleHolders: _createArray(s.curator)
                    })
                ),
                withSlasher: true,
                slasherIndex: VETO_SLASHER_INDEX,
                slasherParams: abi.encode(
                    IVetoSlasher.InitParams({
                        baseParams: IBaseSlasher.BaseParams({isBurnerHook: true}),
                        vetoDuration: s.vetoDuration,
                        resolverSetEpochsDelay: RESOLVER_SET_EPOCHS_DELAY
                    })
                )
            })
        );

        console2.log("SymbioticVault", symbioticVault);
        console2.log("Delegator", delegator);
        console2.log("VetoSlasher", slasher);
        console2.log("RouterBurner", burner);

        return symbioticVault;
    }

    function _deployVaults() internal {
        IMellowSymbioticVaultFactory factory = IMellowSymbioticVaultFactory(MELLOW_VAULT_FACTORY);
        address curator = POND_CURATOR;
        uint48 vaultEpochDuration = POND_VAULT_EPOCH_DURATION;
        uint48 vetoDuration = POND_VETO_DURATION;
        address vaultAdminMultisig = POND_VAULT_ADMIN;
        address vaultProxyAdminMultisig = POND_VAULT_PROXY_ADMIN;
        address asset = POND;
        uint256 vaultLimit = POND_VAULT_LIMIT;
        address globalReceiver = POND_GLOBAL_RECEIVER;
        string memory vaultName = POND_VAULT_NAME;
        string memory vaultSymbol = POND_VAULT_SYMBOL;

        address defaultCollateral = IDefaultCollateralFactory(DEFAULT_COLLATERAL_FACTORY).create(
            asset, 0, vaultAdminMultisig
        );

        address symbioticVault = _deploySymbioticVault(
            Stack({
                asset: asset,
                globalReceiver: globalReceiver,
                vaultAdminMultisig: vaultAdminMultisig,
                vaultProxyAdminMultisig: vaultProxyAdminMultisig,
                vaultEpochDuration: vaultEpochDuration,
                vetoDuration: vetoDuration,
                curator: curator
            })
        );

        (IMellowSymbioticVault vault, IWithdrawalQueue withdrawalQueue) = factory.create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: vaultProxyAdminMultisig,
                limit: vaultLimit,
                symbioticCollateral: defaultCollateral,
                symbioticVault: symbioticVault,
                admin: vaultAdminMultisig,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: vaultName,
                symbol: vaultSymbol
            })
        );

        console2.log("MellowSymbioticVault:", address(vault));
        console2.log("SymbioticWithdrawalQueue:", address(withdrawalQueue));
        console2.log("DefaultCollateral:", defaultCollateral);
        console2.log("VaultAdminMultisig:", vaultAdminMultisig);
        console2.log("VaultProxyAdminMultisig:", vaultProxyAdminMultisig);
        console2.log("Curator:", curator);
        console2.log("VaultEpochDuration:", vaultEpochDuration);
        console2.log("VetoDuration:", vetoDuration);
        console2.log("Asset:", asset);
        console2.log("VaultLimit:", vaultLimit);
        console2.log("GlobalReceiver:", globalReceiver);
        console2.log("VaultName:", vaultName);
        console2.log("VaultSymbol:", vaultSymbol);
    }

    function run() external {
        vm.startBroadcast(uint256(bytes32(vm.envBytes("MAINNET_DEPLOYER"))));
        _deployVaults();
        vm.stopBroadcast();
        revert("success");
    }
}
