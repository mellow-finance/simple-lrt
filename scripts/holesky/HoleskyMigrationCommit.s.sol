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
import "@openzeppelin/contracts/access/AccessControl.sol";

import "../../src/MellowVaultCompat.sol";
import "../../src/Migrator.sol";

interface IDBStrategy {
    function processAll() external;
}

contract Deploy is Script, FactoryDeploy {
    function run() external {
        uint256 vaultAdminPk = uint256(bytes32(vm.envBytes("HOLESKY_VAULT_ADMIN")));
        uint256 migratorAdminPk = uint256(bytes32(vm.envBytes("HOLESKY_MIGRATOR_ADMIN")));

        Migrator migrator = Migrator(0xFB1fB53Dd6d72226b888d8Ae81c520d4b1ec0eD8);
        address vault1 = 0xab6B95B7F8feF87b1297516F5F8Bb8e4F33C6461;
        address strategy1 = 0x9fBd5B6b71BBAdB8756538e2a027b56A3Bda568A;

        // commit.1
        vm.startBroadcast(vaultAdminPk);
        IDBStrategy(strategy1).processAll();
        vm.stopBroadcast();

        // commit.2
        vm.startBroadcast(migratorAdminPk);
        migrator.migrate(vault1);
        vm.stopBroadcast();

        revert("Success");
    }
}
