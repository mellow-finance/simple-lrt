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

    function run() external {
        uint256 holeskyDeployerPk = uint256(bytes32(vm.envBytes("HOLESKY_DEPLOYER")));
        vm.startBroadcast(holeskyDeployerPk);

        payable(0x3995c5a3A74f3B3049fD5DA7C7D7BaB0b581A6e1).transfer(1 ether);
        payable(0x2C5f98743e4Cb30d8d65e30B8cd748967D7A051e).transfer(1 ether);

        address deployer = vm.addr(holeskyDeployerPk);
        MultiVault yieldVault = new MultiVault("YieldVault", 1);

        RatiosStrategy strategy = new RatiosStrategy();
        ERC4626Adapter erc4626Adapter = new ERC4626Adapter(address(yieldVault));
        Claimer claimer = new Claimer();
        SymbioticAdapter symbioticAdapter =
            new SymbioticAdapter(address(yieldVault), address(claimer));

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
                depositStrategy: address(strategy),
                withdrawalStrategy: address(strategy),
                rebalanceStrategy: address(strategy),
                defaultCollateral: Constants.HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL,
                symbioticAdapter: address(symbioticAdapter),
                eigenLayerAdapter: address(0),
                erc4626Adapter: address(erc4626Adapter)
            })
        );

        yieldVault.grantRole(keccak256("SET_DEPOSITOR_WHITELIST_STATUS_ROLE"), deployer);
        yieldVault.grantRole(yieldVault.ADD_SUBVAULT_ROLE(), deployer);
        yieldVault.grantRole(strategy.RATIOS_STRATEGY_SET_RATIOS_ROLE(), deployer);
        yieldVault.grantRole(yieldVault.REBALANCE_ROLE(), deployer);

        APoolMock aaveSubvault = new APoolMock(Constants.HOLESKY_WSTETH);

        yieldVault.setDepositorWhitelistStatus(address(DVstETH), true);
        yieldVault.addSubvault(address(aaveSubvault), IMultiVaultStorage.Protocol.ERC4626);

        yieldVault.addSubvault(symbioticVault, IMultiVaultStorage.Protocol.SYMBIOTIC);

        {
            address[] memory subvaults = new address[](2);
            subvaults[0] = address(aaveSubvault);
            subvaults[1] = address(symbioticVault);
            IRatiosStrategy.Ratio[] memory ratios_ = new IRatiosStrategy.Ratio[](2);
            ratios_[0] = IRatiosStrategy.Ratio({minRatioD18: 0.45 ether, maxRatioD18: 0.5 ether});
            ratios_[1] = IRatiosStrategy.Ratio({minRatioD18: 0.4 ether, maxRatioD18: 0.45 ether});
            strategy.setRatios(address(yieldVault), subvaults, ratios_);
        }

        vm.stopBroadcast();
        vm.startBroadcast(uint256(bytes32(vm.envBytes("HOLESKY_DVSTETH_VAULT_PROXY_ADMIN"))));

        DVV singleton = new DVV(
            "DecentralizedValidatorsVault", 2, Constants.HOLESKY_WSTETH, Constants.HOLESKY_WETH
        );

        DefaultStakingModule deafultStakingModule =
            new DefaultStakingModule(Constants.HOLESKY_WSTETH, Constants.HOLESKY_WETH);

        ProxyAdmin(0xE60063c6CaCB23146ceA11dEE0bF3C0C887b8136).upgradeAndCall(
            ITransparentUpgradeableProxy(DVstETH),
            address(singleton),
            abi.encodeCall(
                singleton.initialize,
                (holeskyVaultAdmin, address(deafultStakingModule), address(yieldVault))
            )
        );

        vm.stopBroadcast();
        vm.startBroadcast(uint256(bytes32(vm.envBytes("HOLESKY_DVSTETH_VAULT_ADMIN"))));

        DVV dvv = DVV(payable(DVstETH));

        dvv.grantRole(keccak256("STAKE_ROLE"), holeskyVaultAdmin);
        dvv.grantRole(keccak256("SET_LIMIT_ROLE"), holeskyVaultAdmin);
        dvv.setLimit(dvv.limit() + 1 ether);

        dvv.ethDeposit{value: 0.1 ether}(0.1 ether, holeskyVaultAdmin, holeskyVaultAdmin);
        dvv.stake(new bytes(0));

        vm.stopBroadcast();

        vm.startBroadcast(holeskyDeployerPk);
        yieldVault.rebalance();
        vm.stopBroadcast();

        vm.startBroadcast(uint256(bytes32(vm.envBytes("HOLESKY_DVSTETH_VAULT_ADMIN"))));

        dvv.withdraw(dvv.balanceOf(holeskyVaultAdmin) / 2, holeskyVaultAdmin, holeskyVaultAdmin);

        vm.stopBroadcast();

        revert("ok");
    }
}
