// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {EthWrapper} from "../../src/EthWrapper.sol";
import "./FactoryDeploy.sol";
import {IDelegatorFactory} from "@symbiotic/core/interfaces/IDelegatorFactory.sol";

import {INetworkRegistry} from "@symbiotic/core/interfaces/INetworkRegistry.sol";
import {IOperatorRegistry} from "@symbiotic/core/interfaces/IOperatorRegistry.sol";
import {ISlasherFactory} from "@symbiotic/core/interfaces/ISlasherFactory.sol";
import {IVaultConfigurator} from "@symbiotic/core/interfaces/IVaultConfigurator.sol";
import {IVaultFactory} from "@symbiotic/core/interfaces/IVaultFactory.sol";
import {
    IBaseDelegator,
    IFullRestakeDelegator,
    IFullRestakeDelegator
} from "@symbiotic/core/interfaces/delegator/IFullRestakeDelegator.sol";
import {INetworkRestakeDelegator} from
    "@symbiotic/core/interfaces/delegator/INetworkRestakeDelegator.sol";
import {INetworkMiddlewareService} from
    "@symbiotic/core/interfaces/service/INetworkMiddlewareService.sol";

import {IBaseSlasher} from "@symbiotic/core/interfaces/slasher/IBaseSlasher.sol";
import {ISlasher} from "@symbiotic/core/interfaces/slasher/ISlasher.sol";
import {IVetoSlasher} from "@symbiotic/core/interfaces/slasher/IVetoSlasher.sol";
import {IVault} from "@symbiotic/core/interfaces/vault/IVault.sol";

import "../../src/MellowVaultCompat.sol";
import "../../src/Migrator.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";

contract Deploy is Script, FactoryDeploy {
    function run() external {
        uint256 vaultAdminPk = uint256(bytes32(vm.envBytes("HOLESKY_VAULT_ADMIN")));
        uint256 ownerOfProxyAdminPk = uint256(bytes32(vm.envBytes("HOLESKY_PROXY_VAULT_ADMIN")));
        uint256 migratorAdminPk = uint256(bytes32(vm.envBytes("HOLESKY_MIGRATOR_ADMIN")));

        Migrator migrator = Migrator(0xFB1fB53Dd6d72226b888d8Ae81c520d4b1ec0eD8);

        address vault1 = 0xab6B95B7F8feF87b1297516F5F8Bb8e4F33C6461;
        address vaultProxyAdmin1 = 0xadB08D2C53D4C47Db0f780B835bA19e71BC19787;
        address strategy1 = 0x9fBd5B6b71BBAdB8756538e2a027b56A3Bda568A;
        // stage.1
        address symbioticVault = 0x7F9dEaA3A26AEA587f8A41C6063D4f93F5a5ee7A;

        // stage.2
        vm.startBroadcast(migratorAdminPk);
        migrator.stageMigration(strategy1, vm.addr(vaultAdminPk), vaultProxyAdmin1, symbioticVault);
        vm.stopBroadcast();

        // stage.3
        vm.startBroadcast(vaultAdminPk);
        IAccessControl(strategy1).grantRole(keccak256("admin_delegate"), vm.addr(vaultAdminPk));
        IAccessControl(strategy1).grantRole(keccak256("operator"), address(migrator));
        vm.stopBroadcast();

        // stage.4
        vm.startBroadcast(ownerOfProxyAdminPk);
        ProxyAdmin(vaultProxyAdmin1).transferOwnership(address(migrator));
        vm.stopBroadcast();
    }

}
