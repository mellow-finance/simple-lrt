// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {EthWrapper} from "../../src/EthWrapper.sol";
import {MellowVaultCompat} from "../../src/MellowVaultCompat.sol";
import {Migrator} from "../../src/Migrator.sol";

import "@openzeppelin/contracts/utils/Create2.sol";

contract Deploy is Script {
    address public immutable migratorAdmin = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    uint256 public immutable migratorDelay = 6 hours;

    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

    bytes32 public SINGLETON_SALT = bytes32(uint256(6641391));
    bytes32 public MIGRATOR_SALT = bytes32(uint256(16415115));
    bytes32 public ETH_WRAPPER_SALT = bytes32(uint256(145570050));

    function run() external {
        vm.startBroadcast(uint256(bytes32(vm.envBytes("MAINNET_DEPLOYER"))));

        MellowVaultCompat singleton =
            new MellowVaultCompat{salt: SINGLETON_SALT}("MellowSymbioticVault", 1);

        Migrator migrator =
            new Migrator{salt: MIGRATOR_SALT}(address(singleton), migratorAdmin, migratorDelay);

        EthWrapper ethWrapper = new EthWrapper{salt: ETH_WRAPPER_SALT}(WETH, WSTETH, STETH);

        vm.stopBroadcast();
    }
}
