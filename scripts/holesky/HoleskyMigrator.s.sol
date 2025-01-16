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

contract Deploy is Script, FactoryDeploy {
    address public immutable migratorAdmin = 0xA9C2CcAB9Bc50e654DCdCEED8B293858a7A7CcB7;
    uint256 public immutable migratorDelay = 6 hours;

    function run() external {
        vm.startBroadcast(uint256(bytes32(vm.envBytes("HOLESKY_DEPLOYER"))));

        MellowVaultCompat singleton =
            new MellowVaultCompat{salt: bytes32(uint256(12345))}("MellowSymbioticVault", 1);
        Migrator migrator = new Migrator{salt: bytes32(uint256(12345))}(
            address(singleton), migratorAdmin, migratorDelay
        );
        console2.log("migrator:", address(migrator));

        vm.stopBroadcast();
        // revert("Success");
    }
}
