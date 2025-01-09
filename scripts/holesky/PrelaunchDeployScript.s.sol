// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

// import "../../test/Imports.sol";
// import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
// import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
// import "forge-std/Script.sol";

// contract Deploy is Script {
//     address private immutable DVstETH = 0x7F31eb85aBE328EBe6DD07f9cA651a6FE623E69B;
//     address private immutable holeskyVaultAdmin = 0x2C5f98743e4Cb30d8d65e30B8cd748967D7A051e;
//     address private immutable symbioticVault = 0x7F9dEaA3A26AEA587f8A41C6063D4f93F5a5ee7A;

//     address private immutable claimer = 0xc551b7EE3577CAE47Ad3bcC919C64Ec53c4fdAB8;
//     address private immutable strategy = 0x35817cB580C927b6Ac68748E0f7D12A6c9515B86;

//     function run() external {
//         uint256 holeskyDeployerPk = uint256(bytes32(vm.envBytes("HOLESKY_DEPLOYER")));
//         vm.startBroadcast(holeskyDeployerPk);

//         MultiVault singleton = new MultiVault("MultiVault", 1);
//         address deployer = vm.addr(holeskyDeployerPk);

//         TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
//             address(singleton),
//             deployer,
//             new bytes(0)
//         );

//         address proxyAdmin = vm.load(
//             address(proxy),
//             0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
//         );

//         MultiVault multiVault = MultiVault(address(proxy));

//         SymbioticAdapter symbioticAdapter =
//             new SymbioticAdapter(address(vault), address(claimer));

//         multiVault.initialize(
//             IMultiVault.InitParams({
//                 admin: deployer,
//                 limit: type(uint256).max,
//                 depositPause: false,
//                 withdrawalPause: false,
//                 depositWhitelist: false,
//                 asset: Constants.HOLESKY_WSTETH,
//                 name: "MultiVault-test-1",
//                 symbol: "MV-1",
//                 depositStrategy: address(strategy),
//                 withdrawalStrategy: address(strategy),
//                 rebalanceStrategy: address(strategy),
//                 defaultCollateral: Constants.HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL,
//                 symbioticAdapter: address(symbioticAdapter),
//                 eigenLayerAdapter: address(0),
//                 erc4626Adapter: address(0)
//             })
//         );

//         yieldVault.grantRole(yieldVault.ADD_SUBVAULT_ROLE(), deployer);
//         yieldVault.grantRole(strategy.RATIOS_STRATEGY_SET_RATIOS_ROLE(), deployer);
//         yieldVault.grantRole(yieldVault.REBALANCE_ROLE(), deployer);

//         yieldVault.addSubvault(symbioticVault, IMultiVaultStorage.Protocol.SYMBIOTIC);

//         {
//             address[] memory subvaults = new address[](1);
//             subvaults[0] = address(symbioticVault);
//             IRatiosStrategy.Ratio[] memory ratios_ = new IRatiosStrategy.Ratio[](1);
//             ratios_[0] = IRatiosStrategy.Ratio({minRatioD18: 0.45 ether, maxRatioD18: 0.5 ether});
//             strategy.setRatios(address(yieldVault), subvaults, ratios_);
//         }

//         multiVault.rebalance();

//         vm.stopBroadcast();

//         revert("ok");
//     }
// }