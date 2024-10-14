// SPDX-License-Identifier: BUSL-1.1
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
    address public constant MAINNET_DEPLOYER = 0x188858AC61a74350116d1CB6958fBc509FD6afA1;

    function run() external {
        uint256 pk = uint256(bytes32(vm.envBytes("MAINNET_DEPLOYER")));
        vm.startBroadcast(pk);
        require(vm.addr(pk) == MAINNET_DEPLOYER, "Deployer key mismatch");

        /*
            1. MellowSymbioticVault Singleton
            2. MellowVaultCompat Singleton
            3. Migrator
            4. MellowSymbioticVaultFactory
            5. EthWrapper
        */

        bytes32 mellowSymbioticVaultSingletonSalt = bytes32(uint256(63161073));
        MellowSymbioticVault mellowSymbioticVault = new MellowSymbioticVault{
            salt: mellowSymbioticVaultSingletonSalt
        }(STORAGE_NAME, STORAGE_VERSION);

        bytes32 mellowVaultCompatSingletonSalt = bytes32(uint256(149034706));
        MellowVaultCompat mellowVaultCompat = new MellowVaultCompat{
            salt: mellowVaultCompatSingletonSalt
        }(STORAGE_NAME, STORAGE_VERSION);

        bytes32 migratorSalt = bytes32(uint256(119546776));
        Migrator migrator = new Migrator{salt: migratorSalt}(
            address(mellowVaultCompat), MAINNET_MIGRATOR_ADMIN, MAINNET_MIGRATOR_DELAY
        );

        bytes32 mellowSymbioticVaultFactorySalt = bytes32(uint256(135218323));
        MellowSymbioticVaultFactory mellowSymbioticVaultFactory = new MellowSymbioticVaultFactory{
            salt: mellowSymbioticVaultFactorySalt
        }(address(mellowSymbioticVault));

        bytes32 ethWrapperSalt = bytes32(uint256(21476937));
        EthWrapper ethWrapper =
            new EthWrapper{salt: ethWrapperSalt}(MAINNET_WETH, MAINNET_WSTETH, MAINNET_STETH);

        console2.log("MellowSymbioticVault Singleton: ", address(mellowSymbioticVault));
        console2.log("MellowVaultCompat Singleton: ", address(mellowVaultCompat));
        console2.log("Migrator: ", address(migrator));
        console2.log("MellowSymbioticVaultFactory: ", address(mellowSymbioticVaultFactory));
        console2.log("EthWrapper: ", address(ethWrapper));

        vm.stopBroadcast();
    }
}
