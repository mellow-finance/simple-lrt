// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";
import "forge-std/Script.sol";

interface ICollector {}

contract Deploy is Script {
    function run() external {
        // uint256 pk = uint256(bytes32(vm.envBytes("HOLESKY_DEPLOYER")));
        // vm.startBroadcast(pk);
        // address deployer = vm.addr(pk);

        // RatiosStrategy strategy = RatiosStrategy(0xba94DF565fA7760003ABD6C295ef514597b4650b);
        // MultiVault vault = MultiVault(0xc3dA07f12344BE2E9212B2B40D3eB9e9aC2dBe27);
        // IsolatedEigenLayerVaultFactory factory =
        //     IsolatedEigenLayerVaultFactory(0x905D71F192eB6F20663E312D0263c412A2654430);

        // address eigenLayerStrategy = 0x7D704507b76571a51d9caE8AdDAbBFd0ba0e63d3;
        // address operator = address(deployer);

        // IDelegationManagerTestnet(Constants.HOLESKY_EL_DELEGATION_MANAGER).registerAsOperator(
        //     address(0), 0, "test-mellow-operator"
        // );

        // ISignatureUtils.SignatureWithExpiry memory signature;
        // (address isolatedVault, address withdrawalQueue) = factory.getOrCreate(
        //     address(vault), operator, eigenLayerStrategy, abi.encode(signature, bytes32(0))
        // );
        // vault.addSubvault(isolatedVault, IMultiVaultStorage.Protocol.EIGEN_LAYER);

        // address[] memory subvaults = new address[](2);
        // subvaults[0] = 0x7F9dEaA3A26AEA587f8A41C6063D4f93F5a5ee7A;
        // subvaults[1] = isolatedVault;

        // IRatiosStrategy.Ratio[] memory ratios_ = new IRatiosStrategy.Ratio[](2);
        // ratios_[0] = IRatiosStrategy.Ratio({
        //     minRatioD18: 0.2 ether,
        //     maxRatioD18: 0.3 ether
        // });
        // ratios_[1] = IRatiosStrategy.Ratio({
        //     minRatioD18: 0.3 ether,
        //     maxRatioD18: 0.4 ether
        // });

        // strategy.setRatios(address(vault), subvaults, ratios_);

        // vault.rebalance();

        // revert("ok");
        // // console2.log(
        // //     ISymbioticAdapter(0x7B223E26E57c23A3E6b8Cfd84bE5175409E8CA56).maxDeposit(0x7F9dEaA3A26AEA587f8A41C6063D4f93F5a5ee7A)
        // // );
        // // vault.grantRole(strategy.RATIOS_STRATEGY_SET_RATIOS_ROLE(), deployer);
        // // vault.grantRole(vault.REBALANCE_ROLE(), deployer);

        // // address[] memory subvaults = new address[](1);
        // // subvaults[0] = 0x7F9dEaA3A26AEA587f8A41C6063D4f93F5a5ee7A;
        // // IRatiosStrategy.Ratio[] memory ratios_ = new IRatiosStrategy.Ratio[](1);
        // // ratios_[0] = IRatiosStrategy.Ratio({
        // //     minRatioD18: 0.5 ether,
        // //     maxRatioD18: 0.8 ether
        // // });
        // // strategy.setRatios(address(vault), subvaults, ratios_);

        // // EthWrapper wrapper = new EthWrapper(
        // //     Constants.HOLESKY_WETH,
        // //     Constants.HOLESKY_WSTETH,
        // //     Constants.HOLESKY_STETH
        // // );

        // // IERC20(Constants.HOLESKY_WSTETH).approve(address(vault), type(uint256).max);
        // // wrapper.deposit{value: 0.1 ether}(
        // //     wrapper.ETH(),
        // //     0.1 ether,
        // //     address(vault),
        // //     deployer,
        // //     deployer
        // // );
        // // vault.rebalance();

        // // address[] memory holders = new address[](1);
        // // holders[0] = deployer;

        // // (address symbioticVault, , ) = IVaultConfigurator(0xD2191FE92987171691d552C219b8caEf186eb9cA).create(
        // //     IVaultConfigurator.InitParams({
        // //         version: 1,
        // //         owner: deployer,
        // //         vaultParams: abi.encode(
        // //             ISymbioticVault.InitParams({
        // //                 collateral: Constants.HOLESKY_WSTETH,
        // //                 burner: address(0),
        // //                 epochDuration: 1 hours,
        // //                 depositWhitelist: false,
        // //                 isDepositLimit: false,
        // //                 depositLimit: 0,
        // //                 defaultAdminRoleHolder: deployer,
        // //                 depositWhitelistSetRoleHolder: deployer,
        // //                 depositorWhitelistRoleHolder: deployer,
        // //                 isDepositLimitSetRoleHolder: deployer,
        // //                 depositLimitSetRoleHolder: deployer
        // //             })
        // //         ),
        // //         delegatorIndex: 0,
        // //         delegatorParams: abi.encode(
        // //             IFullRestakeDelegator.InitParams({
        // //                 baseParams: IBaseDelegator.BaseParams({
        // //                    defaultAdminRoleHolder: deployer,
        // //                    hook: address(0),
        // //                     hookSetRoleHolder: deployer
        // //                 }),
        // //                 networkLimitSetRoleHolders: holders,
        // //                 operatorNetworkLimitSetRoleHolders: holders
        // //             })
        // //         ),
        // //         withSlasher: false,
        // //         slasherIndex: 0,
        // //         slasherParams: new bytes(0)
        // //     })
        // // );

        // // vault.addSubvault(symbioticVault, IMultiVaultStorage.Protocol.SYMBIOTIC);

        // vm.stopBroadcast();
    }
}
