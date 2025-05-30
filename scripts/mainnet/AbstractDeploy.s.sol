// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./AbstractDeployScript.sol";
import "./libraries/EigenLayerDeployLibrary.sol";
import "./libraries/SymbioticDeployLibrary.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("MAINNET_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        // require(deployer == DEPLOYER, "not authorized");
        vm.startBroadcast(deployerPk);

        vm.stopBroadcast();
        revert("success");
    }
}
