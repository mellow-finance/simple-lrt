// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../src/adapters/SymbioticAdapter.sol";
import "../../../src/vaults/MultiVault.sol";
import "./AbstractDeployLibrary.sol";

import {IBurnerRouter} from "@symbiotic/burners/interfaces/router/IBurnerRouter.sol";
import {IBurnerRouterFactory} from "@symbiotic/burners/interfaces/router/IBurnerRouterFactory.sol";
import {IVaultConfigurator} from "@symbiotic/core/interfaces/IVaultConfigurator.sol";
import {IBaseDelegator} from "@symbiotic/core/interfaces/delegator/IBaseDelegator.sol";
import {INetworkRestakeDelegator} from
    "@symbiotic/core/interfaces/delegator/INetworkRestakeDelegator.sol";
import {IBaseSlasher} from "@symbiotic/core/interfaces/slasher/IBaseSlasher.sol";
import {IVetoSlasher} from "@symbiotic/core/interfaces/slasher/IVetoSlasher.sol";
import {IVault} from "@symbiotic/core/interfaces/vault/IVault.sol";

contract SymbioticDeployLibrary is AbstractDeployLibrary {
    struct DeployParams {
        address burnerGlobalReceiver;
        uint48 epochDuration;
        uint48 vetoDuration;
        uint48 burnerDelay;
    }

    address public constant VAULT_CONFIGURATOR = 0x29300b1d3150B4E2b12fE80BE72f365E200441EC;
    address public constant BURNER_ROUTER_FACTORY = 0x99F2B89fB3C363fBafD8d826E5AA77b28bAB70a0;
    address public constant WSTETH_BURNER = 0xdCaC890b14121FD5D925E2589017Be68C2B5B324;
    address public constant WSTETH_DEFAULT_COLLATERAL = 0xC329400492c6ff2438472D4651Ad17389fCb843a;
    address public constant SYMBIOTIC_VAULT_FACTORY = 0xAEb6bdd95c502390db8f52c8909F703E9Af6a346;
    uint32 public constant VAULT_VERSION = 1;
    uint256 public constant RESOLVER_SET_EPOCHS_DELAY = 3;
    uint32 public constant VETO_SLASHER_INDEX = 1;
    uint32 public constant NETWORK_RESTAKE_DELEGATOR_INDEX = 0;

    address public immutable symbioticVaultFactory;
    address public immutable withdrawalQueueImplementation;

    constructor(address symbioticVaultFactory_, address symbioticWithdrawalQueueImplementation_) {
        symbioticVaultFactory = symbioticVaultFactory_;
        withdrawalQueueImplementation = symbioticWithdrawalQueueImplementation_;
    }

    // View functions

    function subvaultType() external pure override returns (uint256) {
        return 0;
    }

    function combineOptions(
        address burnerGlobalReceiver,
        uint48 epochDuration,
        uint48 vetoDuration,
        uint48 burnerDelay
    ) public pure returns (bytes memory) {
        return abi.encode(
            DeployParams({
                burnerGlobalReceiver: burnerGlobalReceiver,
                epochDuration: epochDuration,
                vetoDuration: vetoDuration,
                burnerDelay: burnerDelay
            })
        );
    }

    // Mutable functions

    function deployAndSetAdapter(
        address multiVault,
        DeployScript.Config calldata config,
        bytes calldata /* data */
    ) external override onlyDelegateCall {
        if (address(MultiVault(multiVault).symbioticAdapter()) != address(0)) {
            return;
        }
        address adapter = address(
            new SymbioticAdapter{salt: bytes32(bytes20(multiVault))}(
                multiVault,
                symbioticVaultFactory,
                withdrawalQueueImplementation,
                config.vaultProxyAdmin
            )
        );
        MultiVault(multiVault).setSymbioticAdapter(adapter);
    }

    function deploySubvault(
        address, /* multiVault */
        DeployScript.Config calldata config,
        bytes calldata data
    ) external override onlyDelegateCall returns (address symbioticVault) {
        DeployParams memory params = abi.decode(data, (DeployParams));
        address burner = IBurnerRouterFactory(BURNER_ROUTER_FACTORY).create(
            IBurnerRouter.InitParams({
                owner: config.vaultAdmin,
                collateral: config.asset,
                delay: params.burnerDelay,
                globalReceiver: params.burnerGlobalReceiver,
                networkReceivers: _getNetworkReceivers(),
                operatorNetworkReceivers: new IBurnerRouter.OperatorNetworkReceiver[](0)
            })
        );
        (symbioticVault,,) = IVaultConfigurator(VAULT_CONFIGURATOR).create(
            IVaultConfigurator.InitParams({
                version: VAULT_VERSION,
                owner: config.vaultProxyAdmin,
                vaultParams: abi.encode(
                    IVault.InitParams({
                        collateral: config.asset,
                        burner: burner,
                        epochDuration: params.epochDuration,
                        depositWhitelist: true,
                        isDepositLimit: true,
                        depositLimit: 0,
                        defaultAdminRoleHolder: config.vaultAdmin,
                        depositWhitelistSetRoleHolder: config.vaultAdmin,
                        depositorWhitelistRoleHolder: address(this),
                        isDepositLimitSetRoleHolder: config.vaultAdmin,
                        depositLimitSetRoleHolder: config.curator
                    })
                ),
                delegatorIndex: NETWORK_RESTAKE_DELEGATOR_INDEX,
                delegatorParams: abi.encode(
                    INetworkRestakeDelegator.InitParams({
                        baseParams: IBaseDelegator.BaseParams({
                            defaultAdminRoleHolder: config.vaultAdmin,
                            hook: address(0),
                            hookSetRoleHolder: config.vaultAdmin
                        }),
                        networkLimitSetRoleHolders: _createArray(config.curator),
                        operatorNetworkSharesSetRoleHolders: _createArray(config.curator)
                    })
                ),
                withSlasher: true,
                slasherIndex: VETO_SLASHER_INDEX,
                slasherParams: abi.encode(
                    IVetoSlasher.InitParams({
                        baseParams: IBaseSlasher.BaseParams({isBurnerHook: true}),
                        vetoDuration: params.vetoDuration,
                        resolverSetEpochsDelay: RESOLVER_SET_EPOCHS_DELAY
                    })
                )
            })
        );
    }

    // Internal functions

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
        // Primev network
        networkReceivers[0] = IBurnerRouter.NetworkReceiver({
            network: 0x9101eda106A443A0fA82375936D0D1680D5a64F5,
            receiver: 0xD5881f91270550B8850127f05BD6C8C203B3D33f
        });
    }
}
