// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "../../src/vaults/DVV.sol";
import "../../test/Imports.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/utils/DefaultStakingModule.sol";
import "../../src/vaults/MultiVault.sol";

contract Deploy is Script {
    function run() external {
        address DVstETH = 0x7F31eb85aBE328EBe6DD07f9cA651a6FE623E69B;
        address holeskyVaultAdmin = 0x2C5f98743e4Cb30d8d65e30B8cd748967D7A051e;

        uint256 holeskyDeployerPk = uint256(bytes32(vm.envBytes("HOLESKY_DEPLOYER")));
        vm.startBroadcast(holeskyDeployerPk);
        address deployer = vm.addr(holeskyDeployerPk);
        MultiVault yieldVault = new MultiVault(
            "YieldVault",
            1
        );

        yieldVault.initialize(
            IMultiVault.InitParams({
                admin: deployer,
                limit: type(uint256).max,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: true,
                asset: Constants.HOLESKY_WSTETH,
                name: "YieldVault",
                symbol: "YV",
                depositStrategy: address(0),
                withdrawalStrategy: address(0),
                rebalanceStrategy: address(0),
                defaultCollateral: Constants.HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL,
                symbioticAdapter: address(0),
                eigenLayerAdapter: address(0),
                erc4626Adapter: address(0)
            })
        );

        yieldVault.grantRole(
            keccak256("SET_DEPOSITOR_WHITELIST_STATUS_ROLE"),
            deployer
        );
        yieldVault.setDepositorWhitelistStatus(address(DVstETH), true);
        vm.stopBroadcast();
        
        
        vm.startBroadcast(uint256(bytes32(vm.envBytes("HOLESKY_DVSTETH_VAULT_PROXY_ADMIN"))));
        
        DVV singleton = new DVV(
            "DecentralizedValidatorsVault",
            2,
            Constants.HOLESKY_WSTETH,
            Constants.HOLESKY_WETH
        );

        DefaultStakingModule deafultStakingModule = new DefaultStakingModule(
            Constants.HOLESKY_WSTETH,
            Constants.HOLESKY_WETH
        );

        ProxyAdmin(0xE60063c6CaCB23146ceA11dEE0bF3C0C887b8136).upgradeAndCall(
            ITransparentUpgradeableProxy(DVstETH),
            address(singleton),
            abi.encodeCall(
                singleton.initialize,
                (
                    holeskyVaultAdmin,
                    address(deafultStakingModule),
                    address(yieldVault)
                )
            )
        );

        vm.stopBroadcast();
        revert("ok");
    }
}
