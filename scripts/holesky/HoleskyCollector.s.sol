// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "./collector/Collector.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPk = uint256(bytes32(vm.envBytes("HOLESKY_DEPLOYER")));
        vm.startBroadcast(deployerPk);
        address deployer = vm.addr(deployerPk);
        Collector prevCollector = Collector(0x83d1Da50F63a60F7cdb73bEFc411736447a7a8A8);

        Collector collector = new Collector(prevCollector.wsteth(), prevCollector.weth(), deployer);
        collector.setOracle(prevCollector.oracle());

        SymbioticModule symbioticModule = new SymbioticModule(
            0x7d03b7343BF8d5cEC7C0C27ecE084a20113D15C9,
            0x6F75a4ffF97326A00e52662d82EA4FdE86a2C548,
            0x95CC0a052ae33941877c9619835A233D21D57351,
            256
        );

        collector.setSymbioticModule(symbioticModule);

        INetworkRegistry(0x7d03b7343BF8d5cEC7C0C27ecE084a20113D15C9).registerNetwork();
        IOperatorRegistry(0x6F75a4ffF97326A00e52662d82EA4FdE86a2C548).registerOperator();
        IOptInService(0x95CC0a052ae33941877c9619835A233D21D57351).optIn(
            0x7F9dEaA3A26AEA587f8A41C6063D4f93F5a5ee7A
        );
        IOptInService(0x58973d16FFA900D11fC22e5e2B6840d9f7e13401).optIn(deployer);

        INetworkRestakeDelegator delegator = INetworkRestakeDelegator(
            ISymbioticVault(0x7F9dEaA3A26AEA587f8A41C6063D4f93F5a5ee7A).delegator()
        );
        delegator.setMaxNetworkLimit(0, 100 ether);
        delegator.setNetworkLimit(bytes32(uint256(uint160(deployer)) << 96), 99 ether);
        delegator.setOperatorNetworkShares(
            bytes32(uint256(uint160(deployer)) << 96), deployer, 12345
        );

        collector.collect(
            0xab6B95B7F8feF87b1297516F5F8Bb8e4F33C6461, 0xab6B95B7F8feF87b1297516F5F8Bb8e4F33C6461
        );

        vm.stopBroadcast();
        revert("Success");
    }
}
