// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./Imports.sol";

abstract contract BaseTest is Test {
    SymbioticHelper public immutable symbioticHelper = new SymbioticHelper();
    RandomLib.Storage public rnd = RandomLib.Storage(0);

    function createDefaultMultiVaultWithSymbioticVault(address vaultAdmin)
        internal
        returns (
            MultiVault vault,
            SymbioticAdapter adapter,
            RatiosStrategy strategy,
            address symbioticVault
        )
    {
        vault = new MultiVault("MultiVault", 1);
        adapter = new SymbioticAdapter(address(vault), address(new Claimer()));

        strategy = new RatiosStrategy();

        vault.initialize(
            IMultiVault.InitParams({
                admin: vaultAdmin,
                limit: type(uint256).max,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                asset: Constants.WSTETH(),
                name: "MultiVault test",
                symbol: "MVT",
                depositStrategy: address(strategy),
                withdrawalStrategy: address(strategy),
                rebalanceStrategy: address(strategy),
                defaultCollateral: Constants.WSTETH_SYMBIOTIC_COLLATERAL(),
                symbioticAdapter: address(adapter),
                eigenLayerAdapter: address(0),
                erc4626Adapter: address(0)
            })
        );

        (symbioticVault,,,) = symbioticHelper.createDefaultSymbioticVault(Constants.WSTETH());
        {
            vm.startPrank(vaultAdmin);
            vault.grantRole(strategy.RATIOS_STRATEGY_SET_RATIOS_ROLE(), vaultAdmin);
            vault.grantRole(vault.ADD_SUBVAULT_ROLE(), vaultAdmin);
            vault.addSubvault(address(symbioticVault), IMultiVaultStorage.Protocol.SYMBIOTIC);
            address[] memory subvaults = new address[](1);
            subvaults[0] = symbioticVault;
            IRatiosStrategy.Ratio[] memory ratios = new IRatiosStrategy.Ratio[](1);
            ratios[0] = IRatiosStrategy.Ratio(0.5 ether, 1 ether);
            strategy.setRatios(address(vault), subvaults, ratios);
            vm.stopPrank();
        }
    }

    function testBaseMock() private pure {}
}
