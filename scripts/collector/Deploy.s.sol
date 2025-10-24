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
        CollectorV4 prevCollector = CollectorV4(0x5701D94543B500B8d032a0c67755c312016a2a39);
        CollectorV4 collector =
            new CollectorV4(prevCollector.wsteth(), prevCollector.weth(), deployer);
        collector.setOracle(address(prevCollector.oracle()));

        console2.log(address(collector));

        // collector.collect(
        //     0x5E362eb2c0706Bd1d134689eC75176018385430B,
        //     IERC4626(0x5E362eb2c0706Bd1d134689eC75176018385430B)
        // );

        vm.stopBroadcast();
        revert("ok");
    }
}
