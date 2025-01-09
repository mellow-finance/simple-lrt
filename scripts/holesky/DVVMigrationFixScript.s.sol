// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/utils/DefaultStakingModule.sol";
import "../../src/vaults/DVV.sol";
import "../../src/vaults/MultiVault.sol";
import "../../test/Imports.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "forge-std/Script.sol";

import "./mocks/aave/APoolMock.sol";

contract Deploy is Script {
    address private immutable DVstETH = 0x7F31eb85aBE328EBe6DD07f9cA651a6FE623E69B;
    address private immutable holeskyVaultAdmin = 0x2C5f98743e4Cb30d8d65e30B8cd748967D7A051e;
    address private immutable symbioticVault = 0x7F9dEaA3A26AEA587f8A41C6063D4f93F5a5ee7A;

    RatiosStrategy strategy = RatiosStrategy(0x3069d7B9099C710203756C9324C9aEdDe3CDd90f);
    Claimer claimer = Claimer(0x5bdF0541b7246d03322A3a43dA3C37210C181A74);

    function run() external {
        uint256 holeskyDeployerPk = uint256(bytes32(vm.envBytes("HOLESKY_DEPLOYER")));
        vm.startBroadcast(holeskyDeployerPk);

        address deployer = vm.addr(holeskyDeployerPk);
        MultiVault yieldVault = MultiVault(0x639B8f8391554603D5d73dd38578Db58811E1573);

        ERC4626Adapter erc4626Adapter = new ERC4626Adapter(address(yieldVault));
        SymbioticAdapter symbioticAdapter = new SymbioticAdapter(
            address(yieldVault), address(claimer), Constants.symbioticDeployment().vaultFactory
        );

        yieldVault.grantRole(yieldVault.SET_STRATEGY_ROLE(), deployer);
        yieldVault.grantRole(yieldVault.SET_ADAPTER_ROLE(), deployer);

        yieldVault.setDepositStrategy(address(strategy));
        yieldVault.setWithdrawalStrategy(address(strategy));
        yieldVault.setRebalanceStrategy(address(strategy));

        yieldVault.setERC4626Adapter(address(erc4626Adapter));
        yieldVault.setSymbioticAdapter(address(symbioticAdapter));

        DVV(payable(0x7F31eb85aBE328EBe6DD07f9cA651a6FE623E69B)).ethDeposit{value: 0.1 ether}(
            0.1 ether, deployer, deployer
        );

        yieldVault.rebalance();

        vm.stopBroadcast();

        // revert("ok");
    }
}
