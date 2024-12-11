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

    function testAddSubvault() external {
        MultiVault vault = new MultiVault("MultiVault", 1);

        address vaultAdmin = rnd.randAddress();
        RatiosStrategy strategy = new RatiosStrategy();
        Claimer claimer = new Claimer();
        SymbioticAdapter symbioticAdapter = new SymbioticAdapter(address(vault), address(claimer));
        IsolatedEigenLayerWstETHVaultFactory factory = new IsolatedEigenLayerWstETHVaultFactory(
            Constants.HOLESKY_EL_DELEGATION_MANAGER, address(claimer), Constants.WSTETH()
        );
        EigenLayerAdapter eigenLayerAdapter = new EigenLayerAdapter(
            address(factory),
            address(vault),
            IStrategyManager(Constants.HOLESKY_EL_STRATEGY_MANAGER),
            IRewardsCoordinator(Constants.HOLESKY_EL_REWARDS_COORDINATOR)
        );
        ERC4626Adapter erc4626Adapter = new ERC4626Adapter(address(vault));

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
                symbioticAdapter: address(symbioticAdapter),
                eigenLayerAdapter: address(eigenLayerAdapter),
                erc4626Adapter: address(erc4626Adapter)
            })
        );

        vm.startPrank(vaultAdmin);

        (address symbioticSubvault,,,) =
            symbioticHelper.createDefaultSymbioticVault(Constants.WSTETH());

        vm.expectRevert();
        vault.addSubvault(symbioticSubvault, IMultiVaultStorage.Protocol.SYMBIOTIC);

        vault.grantRole(vault.ADD_SUBVAULT_ROLE(), vaultAdmin);
        vault.addSubvault(symbioticSubvault, IMultiVaultStorage.Protocol.SYMBIOTIC);
        assertEq(vault.subvaultsCount(), 1);

        (address symbioticSubvaultWrongAsset,,,) =
            symbioticHelper.createDefaultSymbioticVault(Constants.STETH());
        vm.expectRevert();
        vault.addSubvault(symbioticSubvaultWrongAsset, IMultiVaultStorage.Protocol.SYMBIOTIC);

        vm.stopPrank();
    }

    function testRemoveSubvault() external {
        MultiVault vault = new MultiVault("MultiVault", 1);

        address vaultAdmin = rnd.randAddress();
        RatiosStrategy strategy = new RatiosStrategy();
        Claimer claimer = new Claimer();
        SymbioticAdapter symbioticAdapter = new SymbioticAdapter(address(vault), address(claimer));
        IsolatedEigenLayerWstETHVaultFactory factory = new IsolatedEigenLayerWstETHVaultFactory(
            Constants.HOLESKY_EL_DELEGATION_MANAGER, address(claimer), Constants.WSTETH()
        );
        EigenLayerAdapter eigenLayerAdapter = new EigenLayerAdapter(
            address(factory),
            address(vault),
            IStrategyManager(Constants.HOLESKY_EL_STRATEGY_MANAGER),
            IRewardsCoordinator(Constants.HOLESKY_EL_REWARDS_COORDINATOR)
        );
        ERC4626Adapter erc4626Adapter = new ERC4626Adapter(address(vault));

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
                symbioticAdapter: address(symbioticAdapter),
                eigenLayerAdapter: address(eigenLayerAdapter),
                erc4626Adapter: address(erc4626Adapter)
            })
        );

        vm.startPrank(vaultAdmin);

        (address symbioticSubvault,,,) =
            symbioticHelper.createDefaultSymbioticVault(Constants.WSTETH());

        vm.expectRevert();
        vault.addSubvault(symbioticSubvault, IMultiVaultStorage.Protocol.SYMBIOTIC);

        vault.grantRole(vault.ADD_SUBVAULT_ROLE(), vaultAdmin);
        vault.addSubvault(symbioticSubvault, IMultiVaultStorage.Protocol.SYMBIOTIC);
        assertEq(vault.subvaultsCount(), 1);

        (address symbioticSubvaultWrongAsset,,,) =
            symbioticHelper.createDefaultSymbioticVault(Constants.STETH());
        vm.expectRevert();
        vault.addSubvault(symbioticSubvaultWrongAsset, IMultiVaultStorage.Protocol.SYMBIOTIC);

        vm.expectRevert();
        vault.removeSubvault(symbioticSubvault);

        vault.grantRole(vault.REMOVE_SUBVAULT_ROLE(), vaultAdmin);
        vault.removeSubvault(symbioticSubvault);
        assertEq(vault.subvaultsCount(), 0);

        vm.expectRevert();
        vault.removeSubvault(symbioticSubvaultWrongAsset);

        vm.stopPrank();
    }

    function testSetDepositStrategy() external {
        MultiVault vault = new MultiVault("MultiVault", 1);

        address vaultAdmin = rnd.randAddress();
        RatiosStrategy strategy = new RatiosStrategy();
        Claimer claimer = new Claimer();
        SymbioticAdapter symbioticAdapter = new SymbioticAdapter(address(vault), address(claimer));
        IsolatedEigenLayerWstETHVaultFactory factory = new IsolatedEigenLayerWstETHVaultFactory(
            Constants.HOLESKY_EL_DELEGATION_MANAGER, address(claimer), Constants.WSTETH()
        );
        EigenLayerAdapter eigenLayerAdapter = new EigenLayerAdapter(
            address(factory),
            address(vault),
            IStrategyManager(Constants.HOLESKY_EL_STRATEGY_MANAGER),
            IRewardsCoordinator(Constants.HOLESKY_EL_REWARDS_COORDINATOR)
        );
        ERC4626Adapter erc4626Adapter = new ERC4626Adapter(address(vault));

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
                symbioticAdapter: address(symbioticAdapter),
                eigenLayerAdapter: address(eigenLayerAdapter),
                erc4626Adapter: address(erc4626Adapter)
            })
        );

        vm.startPrank(vaultAdmin);

        vm.expectRevert();
        vault.setDepositStrategy(address(strategy));

        assertEq(address(vault.depositStrategy()), address(strategy));

        vault.grantRole(vault.SET_STRATEGY_ROLE(), vaultAdmin);
        vault.setDepositStrategy(address(strategy));

        assertEq(address(vault.depositStrategy()), address(strategy));

        vault.setDepositStrategy(address(123));

        assertEq(address(vault.depositStrategy()), address(123));

        vm.expectRevert("MultiVault: deposit strategy cannot be zero address");
        vault.setDepositStrategy(address(0));

        vm.stopPrank();
    }

    function testSetWithdrawalStrategy() external {
        MultiVault vault = new MultiVault("MultiVault", 1);

        address vaultAdmin = rnd.randAddress();
        RatiosStrategy strategy = new RatiosStrategy();
        Claimer claimer = new Claimer();
        SymbioticAdapter symbioticAdapter = new SymbioticAdapter(address(vault), address(claimer));
        IsolatedEigenLayerWstETHVaultFactory factory = new IsolatedEigenLayerWstETHVaultFactory(
            Constants.HOLESKY_EL_DELEGATION_MANAGER, address(claimer), Constants.WSTETH()
        );
        EigenLayerAdapter eigenLayerAdapter = new EigenLayerAdapter(
            address(factory),
            address(vault),
            IStrategyManager(Constants.HOLESKY_EL_STRATEGY_MANAGER),
            IRewardsCoordinator(Constants.HOLESKY_EL_REWARDS_COORDINATOR)
        );
        ERC4626Adapter erc4626Adapter = new ERC4626Adapter(address(vault));

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
                symbioticAdapter: address(symbioticAdapter),
                eigenLayerAdapter: address(eigenLayerAdapter),
                erc4626Adapter: address(erc4626Adapter)
            })
        );

        vm.startPrank(vaultAdmin);

        vm.expectRevert();
        vault.setWithdrawalStrategy(address(strategy));

        assertEq(address(vault.withdrawalStrategy()), address(strategy));

        vault.grantRole(vault.SET_STRATEGY_ROLE(), vaultAdmin);
        vault.setWithdrawalStrategy(address(strategy));

        assertEq(address(vault.withdrawalStrategy()), address(strategy));

        vault.setWithdrawalStrategy(address(123));

        assertEq(address(vault.withdrawalStrategy()), address(123));

        vm.expectRevert("MultiVault: withdrawal strategy cannot be zero address");
        vault.setWithdrawalStrategy(address(0));

        vm.stopPrank();
    }

    function testSetRebalanceStrategy() external {
        MultiVault vault = new MultiVault("MultiVault", 1);

        address vaultAdmin = rnd.randAddress();
        RatiosStrategy strategy = new RatiosStrategy();
        Claimer claimer = new Claimer();
        SymbioticAdapter symbioticAdapter = new SymbioticAdapter(address(vault), address(claimer));
        IsolatedEigenLayerWstETHVaultFactory factory = new IsolatedEigenLayerWstETHVaultFactory(
            Constants.HOLESKY_EL_DELEGATION_MANAGER, address(claimer), Constants.WSTETH()
        );
        EigenLayerAdapter eigenLayerAdapter = new EigenLayerAdapter(
            address(factory),
            address(vault),
            IStrategyManager(Constants.HOLESKY_EL_STRATEGY_MANAGER),
            IRewardsCoordinator(Constants.HOLESKY_EL_REWARDS_COORDINATOR)
        );
        ERC4626Adapter erc4626Adapter = new ERC4626Adapter(address(vault));

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
                symbioticAdapter: address(symbioticAdapter),
                eigenLayerAdapter: address(eigenLayerAdapter),
                erc4626Adapter: address(erc4626Adapter)
            })
        );

        vm.startPrank(vaultAdmin);

        vm.expectRevert();
        vault.setRebalanceStrategy(address(strategy));

        assertEq(address(vault.rebalanceStrategy()), address(strategy));

        vault.grantRole(vault.SET_STRATEGY_ROLE(), vaultAdmin);
        vault.setRebalanceStrategy(address(strategy));

        assertEq(address(vault.rebalanceStrategy()), address(strategy));

        vault.setRebalanceStrategy(address(123));

        assertEq(address(vault.rebalanceStrategy()), address(123));

        vm.expectRevert("MultiVault: rebalance strategy cannot be zero address");
        vault.setRebalanceStrategy(address(0));

        vm.stopPrank();
    }

    function testSetDefaultCollateral() external {
        MultiVault vault = new MultiVault("MultiVault", 1);

        address vaultAdmin = rnd.randAddress();
        RatiosStrategy strategy = new RatiosStrategy();
        Claimer claimer = new Claimer();
        SymbioticAdapter symbioticAdapter = new SymbioticAdapter(address(vault), address(claimer));
        IsolatedEigenLayerWstETHVaultFactory factory = new IsolatedEigenLayerWstETHVaultFactory(
            Constants.HOLESKY_EL_DELEGATION_MANAGER, address(claimer), Constants.WSTETH()
        );
        EigenLayerAdapter eigenLayerAdapter = new EigenLayerAdapter(
            address(factory),
            address(vault),
            IStrategyManager(Constants.HOLESKY_EL_STRATEGY_MANAGER),
            IRewardsCoordinator(Constants.HOLESKY_EL_REWARDS_COORDINATOR)
        );
        ERC4626Adapter erc4626Adapter = new ERC4626Adapter(address(vault));

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
                defaultCollateral: address(0),
                symbioticAdapter: address(symbioticAdapter),
                eigenLayerAdapter: address(eigenLayerAdapter),
                erc4626Adapter: address(erc4626Adapter)
            })
        );

        vm.startPrank(vaultAdmin);

        address wstethDefaultCollateral = Constants.WSTETH_SYMBIOTIC_COLLATERAL();

        vm.expectRevert();
        vault.setDefaultCollateral(wstethDefaultCollateral);

        assertEq(address(vault.defaultCollateral()), address(0));

        vault.grantRole(vault.SET_DEFAULT_COLLATERAL_ROLE(), vaultAdmin);

        vm.expectRevert("MultiVault: default collateral already set or cannot be zero address");
        vault.setDefaultCollateral(address(0));

        vault.setDefaultCollateral(wstethDefaultCollateral);
        assertEq(address(vault.defaultCollateral()), wstethDefaultCollateral);

        vm.expectRevert("MultiVault: default collateral already set or cannot be zero address");
        vault.setDefaultCollateral(wstethDefaultCollateral);

        vm.stopPrank();
    }

    function testSetSymbioticAdapter() external {
        MultiVault vault = new MultiVault("MultiVault", 1);

        address vaultAdmin = rnd.randAddress();
        RatiosStrategy strategy = new RatiosStrategy();
        Claimer claimer = new Claimer();
        SymbioticAdapter symbioticAdapter = new SymbioticAdapter(address(vault), address(claimer));
        IsolatedEigenLayerWstETHVaultFactory factory = new IsolatedEigenLayerWstETHVaultFactory(
            Constants.HOLESKY_EL_DELEGATION_MANAGER, address(claimer), Constants.WSTETH()
        );
        EigenLayerAdapter eigenLayerAdapter = new EigenLayerAdapter(
            address(factory),
            address(vault),
            IStrategyManager(Constants.HOLESKY_EL_STRATEGY_MANAGER),
            IRewardsCoordinator(Constants.HOLESKY_EL_REWARDS_COORDINATOR)
        );
        ERC4626Adapter erc4626Adapter = new ERC4626Adapter(address(vault));

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
                symbioticAdapter: address(symbioticAdapter),
                eigenLayerAdapter: address(eigenLayerAdapter),
                erc4626Adapter: address(erc4626Adapter)
            })
        );

        vm.startPrank(vaultAdmin);

        vm.expectRevert();
        vault.setSymbioticAdapter(address(symbioticAdapter));

        assertEq(address(vault.symbioticAdapter()), address(symbioticAdapter));

        vault.grantRole(vault.SET_ADAPTER_ROLE(), vaultAdmin);
        vault.setSymbioticAdapter(address(symbioticAdapter));

        assertEq(address(vault.symbioticAdapter()), address(symbioticAdapter));

        vault.setSymbioticAdapter(address(123));

        assertEq(address(vault.symbioticAdapter()), address(123));

        vm.expectRevert("MultiVault: adapter cannot be zero address");
        vault.setSymbioticAdapter(address(0));

        vm.stopPrank();
    }

    function testSetEigenLayerAdapter() external {
        MultiVault vault = new MultiVault("MultiVault", 1);

        address vaultAdmin = rnd.randAddress();
        RatiosStrategy strategy = new RatiosStrategy();
        Claimer claimer = new Claimer();
        SymbioticAdapter symbioticAdapter = new SymbioticAdapter(address(vault), address(claimer));
        IsolatedEigenLayerWstETHVaultFactory factory = new IsolatedEigenLayerWstETHVaultFactory(
            Constants.HOLESKY_EL_DELEGATION_MANAGER, address(claimer), Constants.WSTETH()
        );
        EigenLayerAdapter eigenLayerAdapter = new EigenLayerAdapter(
            address(factory),
            address(vault),
            IStrategyManager(Constants.HOLESKY_EL_STRATEGY_MANAGER),
            IRewardsCoordinator(Constants.HOLESKY_EL_REWARDS_COORDINATOR)
        );
        ERC4626Adapter erc4626Adapter = new ERC4626Adapter(address(vault));

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
                symbioticAdapter: address(symbioticAdapter),
                eigenLayerAdapter: address(eigenLayerAdapter),
                erc4626Adapter: address(erc4626Adapter)
            })
        );

        vm.startPrank(vaultAdmin);

        vm.expectRevert();
        vault.setEigenLayerAdapter(address(eigenLayerAdapter));

        assertEq(address(vault.eigenLayerAdapter()), address(eigenLayerAdapter));

        vault.grantRole(vault.SET_ADAPTER_ROLE(), vaultAdmin);
        vault.setEigenLayerAdapter(address(eigenLayerAdapter));
        assertEq(address(vault.eigenLayerAdapter()), address(eigenLayerAdapter));

        vault.setEigenLayerAdapter(address(123));
        assertEq(address(vault.eigenLayerAdapter()), address(123));

        vm.expectRevert("MultiVault: adapter cannot be zero address");
        vault.setEigenLayerAdapter(address(0));

        vm.stopPrank();
    }

    function testSetERC4626Adapter() external {
        MultiVault vault = new MultiVault("MultiVault", 1);

        address vaultAdmin = rnd.randAddress();
        RatiosStrategy strategy = new RatiosStrategy();
        Claimer claimer = new Claimer();
        SymbioticAdapter symbioticAdapter = new SymbioticAdapter(address(vault), address(claimer));
        IsolatedEigenLayerWstETHVaultFactory factory = new IsolatedEigenLayerWstETHVaultFactory(
            Constants.HOLESKY_EL_DELEGATION_MANAGER, address(claimer), Constants.WSTETH()
        );
        EigenLayerAdapter eigenLayerAdapter = new EigenLayerAdapter(
            address(factory),
            address(vault),
            IStrategyManager(Constants.HOLESKY_EL_STRATEGY_MANAGER),
            IRewardsCoordinator(Constants.HOLESKY_EL_REWARDS_COORDINATOR)
        );
        ERC4626Adapter erc4626Adapter = new ERC4626Adapter(address(vault));

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
                symbioticAdapter: address(symbioticAdapter),
                eigenLayerAdapter: address(eigenLayerAdapter),
                erc4626Adapter: address(erc4626Adapter)
            })
        );

        vm.startPrank(vaultAdmin);

        vm.expectRevert();
        vault.setERC4626Adapter(address(erc4626Adapter));

        assertEq(address(vault.erc4626Adapter()), address(erc4626Adapter));

        vault.grantRole(vault.SET_ADAPTER_ROLE(), vaultAdmin);
        vault.setERC4626Adapter(address(erc4626Adapter));
        assertEq(address(vault.erc4626Adapter()), address(erc4626Adapter));

        vault.setERC4626Adapter(address(123));
        assertEq(address(vault.erc4626Adapter()), address(123));

        vm.expectRevert("MultiVault: adapter cannot be zero address");
        vault.setERC4626Adapter(address(0));

        vm.stopPrank();
    }

    function testSetRewardsData() external {
        MultiVault vault = new MultiVault("MultiVault", 1);

        address vaultAdmin = rnd.randAddress();
        RatiosStrategy strategy = new RatiosStrategy();
        Claimer claimer = new Claimer();
        SymbioticAdapter symbioticAdapter = new SymbioticAdapter(address(vault), address(claimer));
        IsolatedEigenLayerWstETHVaultFactory factory = new IsolatedEigenLayerWstETHVaultFactory(
            Constants.HOLESKY_EL_DELEGATION_MANAGER, address(claimer), Constants.WSTETH()
        );
        EigenLayerAdapter eigenLayerAdapter = new EigenLayerAdapter(
            address(factory),
            address(vault),
            IStrategyManager(Constants.HOLESKY_EL_STRATEGY_MANAGER),
            IRewardsCoordinator(Constants.HOLESKY_EL_REWARDS_COORDINATOR)
        );
        ERC4626Adapter erc4626Adapter = new ERC4626Adapter(address(vault));

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
                symbioticAdapter: address(symbioticAdapter),
                eigenLayerAdapter: address(eigenLayerAdapter),
                erc4626Adapter: address(erc4626Adapter)
            })
        );

        vm.startPrank(vaultAdmin);

        vm.expectRevert();
        vault.setRewardsData(
            0,
            IMultiVaultStorage.RewardData({
                token: address(1),
                curatorFeeD6: 0,
                distributionFarm: address(2),
                curatorTreasury: address(0),
                protocol: IMultiVaultStorage.Protocol.SYMBIOTIC,
                data: new bytes(0)
            })
        );

        vault.grantRole(vault.SET_REWARDS_DATA_ROLE(), vaultAdmin);
        vm.expectRevert("MultiVault: curator fee exceeds 100%");
        vault.setRewardsData(
            0,
            IMultiVaultStorage.RewardData({
                token: address(1),
                curatorFeeD6: 1e6 + 1,
                distributionFarm: address(0),
                curatorTreasury: address(0),
                protocol: IMultiVaultStorage.Protocol.SYMBIOTIC,
                data: new bytes(0)
            })
        );

        vm.expectRevert("MultiVault: distribution farm address cannot be zero");
        vault.setRewardsData(
            0,
            IMultiVaultStorage.RewardData({
                token: address(1),
                curatorFeeD6: 1e6,
                distributionFarm: address(0),
                curatorTreasury: address(0),
                protocol: IMultiVaultStorage.Protocol.SYMBIOTIC,
                data: new bytes(0)
            })
        );

        vm.expectRevert("MultiVault: curator treasury address cannot be zero when fee is set");
        vault.setRewardsData(
            0,
            IMultiVaultStorage.RewardData({
                token: address(1),
                curatorFeeD6: 1e6,
                distributionFarm: address(1),
                curatorTreasury: address(0),
                protocol: IMultiVaultStorage.Protocol.SYMBIOTIC,
                data: new bytes(0)
            })
        );

        vm.expectRevert("SymbioticAdapter: invalid reward data");
        vault.setRewardsData(
            0,
            IMultiVaultStorage.RewardData({
                token: address(1),
                curatorFeeD6: 1e6,
                distributionFarm: address(1),
                curatorTreasury: address(2),
                protocol: IMultiVaultStorage.Protocol.SYMBIOTIC,
                data: new bytes(0)
            })
        );

        vm.expectRevert("SymbioticAdapter: invalid reward data");
        vault.setRewardsData(
            0,
            IMultiVaultStorage.RewardData({
                token: address(1),
                curatorFeeD6: 1e6,
                distributionFarm: address(1),
                curatorTreasury: address(2),
                protocol: IMultiVaultStorage.Protocol.SYMBIOTIC,
                data: abi.encode(address(0))
            })
        );

        vault.setRewardsData(
            0,
            IMultiVaultStorage.RewardData({
                token: address(1),
                curatorFeeD6: 1e6,
                distributionFarm: address(1),
                curatorTreasury: address(2),
                protocol: IMultiVaultStorage.Protocol.SYMBIOTIC,
                data: abi.encode(address(1))
            })
        );

        vm.expectRevert("EigenLayerAdapter: invalid reward data");
        vault.setRewardsData(
            0,
            IMultiVaultStorage.RewardData({
                token: address(1),
                curatorFeeD6: 1e6,
                distributionFarm: address(1),
                curatorTreasury: address(2),
                protocol: IMultiVaultStorage.Protocol.EIGEN_LAYER,
                data: new bytes(0)
            })
        );

        vm.expectRevert("EigenLayerAdapter: invalid reward data");
        vault.setRewardsData(
            0,
            IMultiVaultStorage.RewardData({
                token: address(1),
                curatorFeeD6: 1e6,
                distributionFarm: address(1),
                curatorTreasury: address(2),
                protocol: IMultiVaultStorage.Protocol.EIGEN_LAYER,
                data: abi.encode(address(0))
            })
        );

        vm.expectRevert("EigenLayerAdapter: invalid reward data");
        vault.setRewardsData(
            0,
            IMultiVaultStorage.RewardData({
                token: address(1),
                curatorFeeD6: 1e6,
                distributionFarm: address(1),
                curatorTreasury: address(2),
                protocol: IMultiVaultStorage.Protocol.EIGEN_LAYER,
                data: abi.encode(address(1))
            })
        );

        ISignatureUtils.SignatureWithExpiry memory signature;
        (address isolatedVault,) = factory.getOrCreate(
            address(vault),
            0xbF8a8B0d0450c8812ADDf04E1BcB7BfBA0E82937,
            0x7D704507b76571a51d9caE8AdDAbBFd0ba0e63d3,
            abi.encode(signature, bytes32(0))
        );

        vault.setRewardsData(
            0,
            IMultiVaultStorage.RewardData({
                token: address(1),
                curatorFeeD6: 1e6,
                distributionFarm: address(1),
                curatorTreasury: address(2),
                protocol: IMultiVaultStorage.Protocol.EIGEN_LAYER,
                data: abi.encode(isolatedVault)
            })
        );

        vm.expectRevert();
        vault.setRewardsData(
            0,
            IMultiVaultStorage.RewardData({
                token: address(1),
                curatorFeeD6: 1e6,
                distributionFarm: address(1),
                curatorTreasury: address(2),
                protocol: IMultiVaultStorage.Protocol.ERC4626,
                data: new bytes(0)
            })
        );

        // removal of rewards data
        vault.setRewardsData(
            0,
            IMultiVaultStorage.RewardData({
                token: address(0),
                curatorFeeD6: 1e6,
                distributionFarm: address(1),
                curatorTreasury: address(2),
                protocol: IMultiVaultStorage.Protocol.ERC4626,
                data: new bytes(0)
            })
        );

        vm.stopPrank();
    }

    function testPushRewards() external {
        MultiVault vault = new MultiVault("MultiVault", 1);

        address vaultAdmin = rnd.randAddress();
        RatiosStrategy strategy = new RatiosStrategy();
        Claimer claimer = new Claimer();
        SymbioticAdapter symbioticAdapter = new SymbioticAdapter(address(vault), address(claimer));
        IsolatedEigenLayerWstETHVaultFactory factory = new IsolatedEigenLayerWstETHVaultFactory(
            Constants.HOLESKY_EL_DELEGATION_MANAGER, address(claimer), Constants.WSTETH()
        );
        EigenLayerAdapter eigenLayerAdapter = new EigenLayerAdapter(
            address(factory),
            address(vault),
            IStrategyManager(Constants.HOLESKY_EL_STRATEGY_MANAGER),
            IRewardsCoordinator(Constants.HOLESKY_EL_REWARDS_COORDINATOR)
        );
        ERC4626Adapter erc4626Adapter = new ERC4626Adapter(address(vault));

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
                symbioticAdapter: address(symbioticAdapter),
                eigenLayerAdapter: address(eigenLayerAdapter),
                erc4626Adapter: address(erc4626Adapter)
            })
        );

        address distributorFarm = rnd.randAddress();
        address curatorTreasury = rnd.randAddress();

        vm.startPrank(vaultAdmin);
        vault.grantRole(vault.SET_REWARDS_DATA_ROLE(), vaultAdmin);
        vault.setRewardsData(
            0,
            IMultiVaultStorage.RewardData({
                token: address(1),
                curatorFeeD6: 1e5,
                distributionFarm: distributorFarm,
                curatorTreasury: curatorTreasury,
                protocol: IMultiVaultStorage.Protocol.SYMBIOTIC,
                data: abi.encode(address(1))
            })
        );

        ISignatureUtils.SignatureWithExpiry memory signature;
        (address isolatedVault,) = factory.getOrCreate(
            address(vault),
            0xbF8a8B0d0450c8812ADDf04E1BcB7BfBA0E82937,
            0x7D704507b76571a51d9caE8AdDAbBFd0ba0e63d3,
            abi.encode(signature, bytes32(0))
        );

        vault.setRewardsData(
            1,
            IMultiVaultStorage.RewardData({
                token: address(1),
                curatorFeeD6: 1e5,
                distributionFarm: distributorFarm,
                curatorTreasury: curatorTreasury,
                protocol: IMultiVaultStorage.Protocol.EIGEN_LAYER,
                data: abi.encode(isolatedVault)
            })
        );

        vm.stopPrank();
    }
}
