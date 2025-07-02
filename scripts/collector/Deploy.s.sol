// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./CollectorV3.sol";
import "./CollectorV4.sol";
import "./modules/EigenLayerModule.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPk = uint256(0);
        address deployer = vm.addr(deployerPk);
        vm.startBroadcast(deployerPk);
        CollectorV3 prevCollector = CollectorV3(0x33134822BB77a4F4d51f01b34DEbB2A6068A2F18);
        CollectorV4 collector =
            new CollectorV4(prevCollector.wsteth(), prevCollector.weth(), deployer);
        collector.setOracle(address(prevCollector.oracle()));
        vm.stopBroadcast();
        // revert("ok");
    }
}
