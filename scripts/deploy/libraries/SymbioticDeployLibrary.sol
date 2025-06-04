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

    // Symbiotic deployment
    address public immutable vaultConfigurator;
    address public immutable burnerRouterFactory;
    uint32 public immutable vaultVersion;
    uint256 public immutable resolverSetEpochsDelay;
    uint32 public immutable vetoSlasherIndex;
    uint32 public immutable networkRestakeDelegatorIndex;
    address public immutable symbioticVaultFactory;
    // Mellow deployment
    address public immutable withdrawalQueueImplementation;

    constructor(
        address vaultConfigurator_,
        address burnerRouterFactory_,
        uint32 vaultVersion_,
        uint256 resolverSetEpochsDelay_,
        uint32 vetoSlasherIndex_,
        uint32 networkRestakeDelegatorIndex_,
        address symbioticVaultFactory_,
        address symbioticWithdrawalQueueImplementation_
    ) {
        vaultConfigurator = vaultConfigurator_;
        burnerRouterFactory = burnerRouterFactory_;
        vaultVersion = vaultVersion_;
        resolverSetEpochsDelay = resolverSetEpochsDelay_;
        vetoSlasherIndex = vetoSlasherIndex_;
        networkRestakeDelegatorIndex = networkRestakeDelegatorIndex_;
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
        bytes calldata, /* data */
        bytes32 salt
    ) external override onlyDelegateCall {
        if (address(MultiVault(multiVault).symbioticAdapter()) != address(0)) {
            return;
        }
        address adapter = address(
            new SymbioticAdapter{salt: salt}(
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
        bytes calldata data,
        bytes32 /* salt */
    ) external override onlyDelegateCall returns (address symbioticVault) {
        DeployParams memory params = abi.decode(data, (DeployParams));
        address burner = IBurnerRouterFactory(burnerRouterFactory).create(
            IBurnerRouter.InitParams({
                owner: config.vaultAdmin,
                collateral: config.asset,
                delay: params.burnerDelay,
                globalReceiver: params.burnerGlobalReceiver,
                networkReceivers: _getNetworkReceivers(),
                operatorNetworkReceivers: new IBurnerRouter.OperatorNetworkReceiver[](0)
            })
        );
        (symbioticVault,,) = IVaultConfigurator(vaultConfigurator).create(
            IVaultConfigurator.InitParams({
                version: vaultVersion,
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
                delegatorIndex: networkRestakeDelegatorIndex,
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
                slasherIndex: vetoSlasherIndex,
                slasherParams: abi.encode(
                    IVetoSlasher.InitParams({
                        baseParams: IBaseSlasher.BaseParams({isBurnerHook: true}),
                        vetoDuration: params.vetoDuration,
                        resolverSetEpochsDelay: resolverSetEpochsDelay
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
