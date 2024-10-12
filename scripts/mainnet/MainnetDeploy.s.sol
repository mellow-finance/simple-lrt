// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {EthWrapper} from "../../src/EthWrapper.sol";

import {MellowSymbioticVault} from "../../src/MellowSymbioticVault.sol";
import {MellowSymbioticVaultFactory} from "../../src/MellowSymbioticVaultFactory.sol";
import {MellowVaultCompat} from "../../src/MellowVaultCompat.sol";
import {Migrator} from "../../src/Migrator.sol";

contract Deploy is Script {
    // "mellow.simple-lrt.storage.MellowSymbioticVaultStorage", name_, version_
    bytes32 public constant STORAGE_NAME = "MellowSymbioticVault";
    uint256 public constant STORAGE_VERSION = 1;

    address public constant MAINNET_MIGRATOR_ADMIN = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    uint256 public constant MAINNET_MIGRATOR_DELAY = 1 days;

    address public constant MAINNET_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant MAINNET_WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant MAINNET_STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

    function run() external {
        vm.startBroadcast(uint256(bytes32(vm.envBytes("MAINNET_DEPLOYER"))));

        /*
            1. MellowSymbioticVault Singleton
            2. MellowVaultCompat Singleton
            3. Migrator
            4. MellowSymbioticVaultFactory
            5. EthWrapper
        */

        MellowSymbioticVault mellowSymbioticVaultSingleton =
            new MellowSymbioticVault(STORAGE_NAME, STORAGE_VERSION);

        MellowVaultCompat mellowVaultCompatSingleton =
            new MellowVaultCompat(STORAGE_NAME, STORAGE_VERSION);

        Migrator migrator = new Migrator(
            address(mellowVaultCompatSingleton), MAINNET_MIGRATOR_ADMIN, MAINNET_MIGRATOR_DELAY
        );

        MellowSymbioticVaultFactory mellowSymbioticVaultFactory =
            new MellowSymbioticVaultFactory(address(mellowSymbioticVaultSingleton));

        EthWrapper ethWrapper = new EthWrapper(MAINNET_WETH, MAINNET_WSTETH, MAINNET_STETH);

        console2.log("MellowSymbioticVault Singleton: ", address(mellowSymbioticVaultSingleton));
        console2.log("MellowVaultCompat Singleton: ", address(mellowVaultCompatSingleton));
        console2.log("Migrator: ", address(migrator));
        console2.log("MellowSymbioticVaultFactory: ", address(mellowSymbioticVaultFactory));
        console2.log("EthWrapper: ", address(ethWrapper));

        vm.stopBroadcast();

        revert("Success");
    }
}
