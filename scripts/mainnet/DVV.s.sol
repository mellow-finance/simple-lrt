// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/utils/MigratorDVV.sol";
import "../../src/vaults/DVV.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("MAINNET_DEPLOYER")));
        address deployer = vm.addr(deployerPk);
        require(deployer == 0x188858AC61a74350116d1CB6958fBc509FD6afA1, "not authorized");
        vm.startBroadcast(deployerPk);

        DVV dvvImplementation = new DVV{salt: bytes32(uint256(0xae4d1))}();
        MigratorDVV migratorDVV = new MigratorDVV{salt: bytes32(uint256(0xb75716))}(
            address(dvvImplementation), 11750 ether
        );

        vm.stopBroadcast();
    }
}
