// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/utils/DefaultStakingModule.sol";
import "../../src/vaults/DVV.sol";
import "../../src/vaults/MultiVault.sol";
import "../../test/Imports.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    function run() external {
        uint256 holeskyDeployerPk = uint256(bytes32(vm.envBytes("HOLESKY_DEPLOYER")));
        vm.startBroadcast(holeskyDeployerPk);

        address deployer = vm.addr(holeskyDeployerPk);

        vm.stopBroadcast();

        // revert("ok");
    }
}
