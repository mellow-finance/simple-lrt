// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/utils/WhitelistedEthWrapper.sol";
import "./MultiVaultDeployScript.sol";
import {IBurnerRouter} from "@symbiotic/burners/interfaces/router/IBurnerRouter.sol";
import {IBurnerRouterFactory} from "@symbiotic/burners/interfaces/router/IBurnerRouterFactory.sol";
import {IVaultConfigurator} from "@symbiotic/core/interfaces/IVaultConfigurator.sol";
import {IBaseDelegator} from "@symbiotic/core/interfaces/delegator/IBaseDelegator.sol";
import {INetworkRestakeDelegator} from
    "@symbiotic/core/interfaces/delegator/INetworkRestakeDelegator.sol";
import {IBaseSlasher} from "@symbiotic/core/interfaces/slasher/IBaseSlasher.sol";
import {IVetoSlasher} from "@symbiotic/core/interfaces/slasher/IVetoSlasher.sol";
import {IVault} from "@symbiotic/core/interfaces/vault/IVault.sol";

contract LidoV3DeployScript {
    struct Config {
        address vaultAdmin;
        address vaultProxyAdmin;
        address curator;
        address asset;
        address defaultCollateral;
        address burnerGlobalReceiver;
        address depositWrapper;
        string name;
        string symbol;
        uint256 limit;
        uint48 epochDuration;
        uint48 vetoDuration;
        uint48 burnerDelay;
        uint64 minRatioD18;
        uint64 maxRatioD18;
        bytes32 salt;
    }

    struct Deployment {
        address vault;
        address symbioticVault;
        address withdrawalQueue;
        address slasher;
        address burner;
        address delegator;
        bytes32 mvSalt;
    }

    // Symbiotic deployment:
    address public constant VAULT_CONFIGURATOR = 0x29300b1d3150B4E2b12fE80BE72f365E200441EC;
    address public constant BURNER_ROUTER_FACTORY = 0x99F2B89fB3C363fBafD8d826E5AA77b28bAB70a0;
    address public constant WSTETH_BURNER = 0xdCaC890b14121FD5D925E2589017Be68C2B5B324;
    address public constant WSTETH_DEFAULT_COLLATERAL = 0xC329400492c6ff2438472D4651Ad17389fCb843a;
    address public constant SYMBIOTIC_VAULT_FACTORY = 0xAEb6bdd95c502390db8f52c8909F703E9Af6a346;
    uint32 public constant VAULT_VERSION = 1;
    uint256 public constant RESOLVER_SET_EPOCHS_DELAY = 3;
    uint32 public constant VETO_SLASHER_INDEX = 1;
    uint32 public constant NETWORK_RESTAKE_DELEGATOR_INDEX = 0;

    // Mellow deployments
    WhitelistedEthWrapper public immutable depositWrapper =
        WhitelistedEthWrapper(payable(0xfD4a4922d1AFe70000Ce0Ec6806454e78256504e));
    MultiVaultDeployScript public immutable deployScript =
        MultiVaultDeployScript(0x0159AEA190C7bEa09873B9b42Fe8fD836DB8a254);

    // Mutable functions

    function deploy(Config calldata config) public returns (Deployment memory $) {
        _deploySymbioticVault(config, $);
        _deployMultiVaults(config, $);
        emit Deployed($.vault, $.mvSalt, config, $);
    }

    receive() external payable {}

    // Internal functions

    function _deployMultiVaults(Config calldata config, Deployment memory $) internal {
        (MultiVault multiVault,, MultiVaultDeployScript.DeployParams memory dp) = deployScript
            .deploy(
            MultiVaultDeployScript.DeployParams({
                admin: config.vaultAdmin,
                proxyAdmin: config.vaultProxyAdmin,
                curator: config.curator,
                symbioticVault: $.symbioticVault,
                depositWrapper: config.depositWrapper,
                asset: config.asset,
                defaultCollateral: config.defaultCollateral,
                limit: config.limit,
                depositPause: false,
                withdrawalPause: false,
                name: config.name,
                symbol: config.symbol,
                minRatioD18: config.minRatioD18,
                maxRatioD18: config.maxRatioD18,
                salt: config.salt
            })
        );
        $.mvSalt = deployScript.calculateSalt(dp);

        if ($.symbioticVault != address(0)) {
            IVault($.symbioticVault).setDepositorWhitelistStatus(address(multiVault), true);
            IAccessControl($.symbioticVault).renounceRole(
                IVault($.symbioticVault).DEPOSIT_WHITELIST_SET_ROLE(), address(this)
            );
        }

        if (address(depositWrapper) == config.depositWrapper) {
            depositWrapper.deposit{value: 1 gwei}(
                depositWrapper.ETH(), 1 gwei, address(multiVault), address(this), address(this)
            );
        }

        $.vault = address(multiVault);
        $.withdrawalQueue = address(multiVault.subvaultAt(0).withdrawalQueue);
    }

    function _deploySymbioticVault(Config calldata config, Deployment memory $) internal {
        $.burner = IBurnerRouterFactory(BURNER_ROUTER_FACTORY).create(
            IBurnerRouter.InitParams({
                owner: config.vaultAdmin,
                collateral: config.asset,
                delay: config.burnerDelay,
                globalReceiver: config.burnerGlobalReceiver,
                networkReceivers: _getNetworkReceivers(),
                operatorNetworkReceivers: new IBurnerRouter.OperatorNetworkReceiver[](0)
            })
        );
        ($.symbioticVault, $.delegator, $.slasher) = IVaultConfigurator(VAULT_CONFIGURATOR).create(
            IVaultConfigurator.InitParams({
                version: VAULT_VERSION,
                owner: config.vaultProxyAdmin,
                vaultParams: abi.encode(
                    IVault.InitParams({
                        collateral: config.asset,
                        burner: $.burner,
                        epochDuration: config.epochDuration,
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
                        vetoDuration: config.vetoDuration,
                        resolverSetEpochsDelay: RESOLVER_SET_EPOCHS_DELAY
                    })
                )
            })
        );
    }

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
        // Primev network receiver
        networkReceivers[0] = IBurnerRouter.NetworkReceiver({
            network: 0x9101eda106A443A0fA82375936D0D1680D5a64F5,
            receiver: 0xD5881f91270550B8850127f05BD6C8C203B3D33f
        });
    }

    event Deployed(
        address indexed vault, bytes32 indexed mvSalt, Config config, Deployment deployment
    );
}
