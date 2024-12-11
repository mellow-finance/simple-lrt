// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

contract Unit is BaseTest {
    using RandomLib for RandomLib.Storage;

    function testConstructor() external {
        MultiVault c = new MultiVault("test", 1);
        assertNotEq(address(c), address(0));
    }

    function testInitialize() external {
        MultiVault c = new MultiVault("test", 1);

        assertEq(c.getRoleMemberCount(c.DEFAULT_ADMIN_ROLE()), 0);
        assertEq(c.limit(), 0);
        assertEq(c.depositPause(), false);
        assertEq(c.withdrawalPause(), false);
        assertEq(c.depositWhitelist(), false);
        assertEq(c.asset(), address(0));
        assertEq(c.name(), "");
        assertEq(c.symbol(), "");
        assertEq(address(c.depositStrategy()), address(0));
        assertEq(address(c.withdrawalStrategy()), address(0));
        assertEq(address(c.rebalanceStrategy()), address(0));
        assertEq(address(c.defaultCollateral()), address(0));
        assertEq(address(c.symbioticAdapter()), address(0));
        assertEq(address(c.eigenLayerAdapter()), address(0));
        assertEq(address(c.erc4626Adapter()), address(0));

        IMultiVault.InitParams memory initParams;
        initParams.admin = rnd.randAddress();
        initParams.limit = rnd.randInt(100 ether);
        initParams.depositPause = true;
        initParams.withdrawalPause = true;
        initParams.depositWhitelist = true;
        initParams.asset = Constants.WSTETH();
        initParams.name = "MultiVault test";
        initParams.symbol = "MVTEST";
        initParams.depositStrategy = address(1);
        initParams.withdrawalStrategy = address(2);
        initParams.rebalanceStrategy = address(3);
        initParams.defaultCollateral = Constants.WSTETH_SYMBIOTIC_COLLATERAL();
        initParams.symbioticAdapter = address(4);
        initParams.eigenLayerAdapter = address(5);
        initParams.erc4626Adapter = address(6);
        c.initialize(initParams);

        assertEq(c.getRoleMemberCount(c.DEFAULT_ADMIN_ROLE()), 1);
        assertEq(c.limit(), initParams.limit);
        assertEq(c.depositPause(), initParams.depositPause);
        assertEq(c.withdrawalPause(), initParams.withdrawalPause);
        assertEq(c.depositWhitelist(), initParams.depositWhitelist);
        assertEq(c.asset(), initParams.asset);
        assertEq(c.name(), initParams.name);
        assertEq(c.symbol(), initParams.symbol);
        assertEq(address(c.depositStrategy()), initParams.depositStrategy);
        assertEq(address(c.withdrawalStrategy()), initParams.withdrawalStrategy);
        assertEq(address(c.rebalanceStrategy()), initParams.rebalanceStrategy);
        assertEq(address(c.defaultCollateral()), initParams.defaultCollateral);
        assertEq(address(c.symbioticAdapter()), initParams.symbioticAdapter);
        assertEq(address(c.eigenLayerAdapter()), initParams.eigenLayerAdapter);
        assertEq(address(c.erc4626Adapter()), initParams.erc4626Adapter);
    }
}
