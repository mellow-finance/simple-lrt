// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "forge-std/Script.sol";

import "./MultiVaultDeployScript.sol";

import {IVaultConfigurator} from "@symbiotic/core/interfaces/IVaultConfigurator.sol";
import {IBaseDelegator} from "@symbiotic/core/interfaces/delegator/IBaseDelegator.sol";
import {INetworkRestakeDelegator} from
    "@symbiotic/core/interfaces/delegator/INetworkRestakeDelegator.sol";
import {IBaseSlasher} from "@symbiotic/core/interfaces/slasher/IBaseSlasher.sol";
import {IVetoSlasher} from "@symbiotic/core/interfaces/slasher/IVetoSlasher.sol";
import {IVault} from "@symbiotic/core/interfaces/vault/IVault.sol";

contract Deploy is Script {
    uint32 public constant VAULT_VERSION = 1;

    address public constant VAULT_CONFIGURATOR = 0xD2191FE92987171691d552C219b8caEf186eb9cA;

    uint32 public constant VETO_SLASHER_INDEX = 1;
    uint32 public constant NETWORK_RESTAKE_DELEGATOR_INDEX = 0;

    uint256 public constant RESOLVER_SET_EPOCHS_DELAY = 3;

    address public constant WSTETH = 0x004E9C3EF86bc1ca1f0bB5C7662861Ee93350568;

    address public constant DEFAULT_COLLATERAL_FACTORY = 0x1BC8FCFbE6Aa17e4A7610F51B888f34583D202Ec;

    uint48 public constant VAULT_EPOCH_DURATION = 30 minutes;
    uint48 public constant VETO_DURATION = 15 minutes;

    uint256 public constant SYMBIOTIC_VAULT_LIMIT = 100 ether;

    function _createArray(address curator) internal pure returns (address[] memory a) {
        a = new address[](1);
        a[0] = curator;
    }

    struct Stack {
        address asset;
        address vaultAdminMultisig;
        address vaultProxyAdminMultisig;
        address curator;
        uint48 vaultEpochDuration;
        uint48 vetoDuration;
    }

    function _deploySymbioticVault(Stack memory s) internal returns (address) {
        IVaultConfigurator vaultConfigurator = IVaultConfigurator(VAULT_CONFIGURATOR);
        (address symbioticVault, address delegator, address slasher) = vaultConfigurator.create(
            IVaultConfigurator.InitParams({
                version: VAULT_VERSION,
                owner: s.vaultProxyAdminMultisig,
                vaultParams: abi.encode(
                    IVault.InitParams({
                        collateral: s.asset,
                        burner: address(0xdead),
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

        return symbioticVault;
    }

    function run() external {
        uint256 holeskyDeployerPk = uint256(bytes32(vm.envBytes("HOLESKY_DEPLOYER")));
        vm.startBroadcast(holeskyDeployerPk);

        address deployer = vm.addr(holeskyDeployerPk);
        MultiVault multiVault = MultiVault(0x9F694B85a80ef52Fd7A3D697e56647dDAd559789);
        address[3] memory curators = [
            0xA344EFc119B50F554d66Da55928D9dF1fA177D55,
            0xa9f8D7E123784ED914724B8d11D5e669De5cC4d8,
            0xad79579eEceF31f4719426232D7b527B17b84f85
        ];

        for (uint256 i = 0; i < curators.length; i++) {
            multiVault.grantRole(multiVault.REBALANCE_ROLE(), curators[i]);
        }
        // Stack memory s = Stack({
        //     asset: Constants.WSTETH(),
        //     vaultAdminMultisig: deployer,
        //     vaultProxyAdminMultisig: deployer,
        //     curator: deployer,
        //     vaultEpochDuration: VAULT_EPOCH_DURATION,
        //     vetoDuration: VETO_DURATION
        // });

        // address symbioticVault2 = _deploySymbioticVault(s);
        // address symbioticVault3 = _deploySymbioticVault(s);

        // multiVault.grantRole(
        //     multiVault.ADD_SUBVAULT_ROLE(),
        //     deployer
        // );
        // multiVault.addSubvault(symbioticVault2, IMultiVaultStorage.Protocol.SYMBIOTIC);
        // multiVault.addSubvault(symbioticVault3, IMultiVaultStorage.Protocol.SYMBIOTIC);

        // for (uint256 i = 0; i < curators.length; i++) {
        //     multiVault.grantRole(keccak256("RATIOS_STRATEGY_SET_RATIOS_ROLE"), curators[i]);
        // }

        vm.stopBroadcast();

        // revert("ok");
    }
}
