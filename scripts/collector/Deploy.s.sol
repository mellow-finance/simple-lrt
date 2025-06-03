// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./CollectorV3.sol";
import "./modules/EigenLayerModule.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("MAINNET_TEST_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        require(deployer == 0x5C0F3DE4ba6AD53bb8E27f965170A52671e525Bf, "not authorized");
        vm.startBroadcast(deployerPk);

        CollectorV3 prevCollector = CollectorV3(0x33134822BB77a4F4d51f01b34DEbB2A6068A2F18);
        CollectorV3 collector = new CollectorV3{salt: bytes32(uint256(0x34cd553))}(
            prevCollector.wsteth(), prevCollector.weth(), deployer
        );
        collector.setOracle(address(prevCollector.oracle()));

        vm.stopBroadcast();
    }
}
