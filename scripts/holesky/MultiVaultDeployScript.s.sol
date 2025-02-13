// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "forge-std/Script.sol";

import "./MultiVaultDeployScript.sol";

contract Deploy is Script {
    address private immutable DVstETH = 0x7F31eb85aBE328EBe6DD07f9cA651a6FE623E69B;
    address private immutable holeskyVaultAdmin = 0x2C5f98743e4Cb30d8d65e30B8cd748967D7A051e;
    address private immutable symbioticVault = 0x7F9dEaA3A26AEA587f8A41C6063D4f93F5a5ee7A;

    function run() external {
        uint256 holeskyDeployerPk = uint256(bytes32(vm.envBytes("HOLESKY_DEPLOYER")));
        vm.startBroadcast(holeskyDeployerPk);

        address deployer = vm.addr(holeskyDeployerPk);

        MultiVaultDeployScript deployScript =
            new MultiVaultDeployScript(0x407A039D94948484D356eFB765b3c74382A050B4);

        MultiVaultDeployScript.DeployParams memory deployParams;
        deployParams.singleton = address(new MultiVault("MultiVault", 1));
        address claimer = address(new Claimer());
        address ratiosStrategy = address(new RatiosStrategy());
        deployParams.symbioticWithdrawalQueueSingleton =
            address(new SymbioticWithdrawalQueue(claimer));
        deployParams.symbioticVault = symbioticVault;
        deployParams.admin = deployer;
        deployParams.proxyAdmin = deployer;
        deployParams.curator = deployer;
        deployParams.isWhitelistedWrapper = true;
        WhitelistedEthWrapper ethWrapper =
            new WhitelistedEthWrapper(Constants.WETH(), Constants.WSTETH(), Constants.STETH());
        deployParams.ethWrapper = address(ethWrapper);
        deployParams.ratio = IRatiosStrategy.Ratio({minRatioD18: 0.5 ether, maxRatioD18: 0.9 ether});

        for (uint256 i = 0; i < 5; i++) {
            deployParams.initParams = IMultiVault.InitParams({
                admin: deployer,
                limit: 100 ether,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: true,
                asset: Constants.WSTETH(),
                name: string.concat("Mellow Pre-deposit Vault ", vm.toString(i + 1)),
                symbol: string.concat("MPV-", vm.toString(i + 1)),
                depositStrategy: address(ratiosStrategy),
                withdrawalStrategy: address(ratiosStrategy),
                rebalanceStrategy: address(ratiosStrategy),
                defaultCollateral: Constants.HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL,
                symbioticAdapter: address(0),
                eigenLayerAdapter: address(0),
                erc4626Adapter: address(0)
            });
            (MultiVault multiVault, address symbioticAdapter) = deployScript.deploy(deployParams);
            console2.log(
                "Vault name %s, address %s, symbioticAdapter %s",
                multiVault.name(),
                address(multiVault),
                address(symbioticAdapter)
            );

            ethWrapper.deposit{value: 0.001 ether}(
                ethWrapper.ETH(), 0.001 ether, address(multiVault), deployer, deployer
            );
        }
        vm.stopBroadcast();

        // revert("ok");
    }
}
