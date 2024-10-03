// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

import "../mocks/MockMellowSymbioticVault.sol";
import "../mocks/MockMellowSymbioticVaultExt.sol";
import "../mocks/MockSymbioticFarm.sol";

contract Unit is BaseTest {
    address wsteth = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;
    address steth = 0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034;
    address weth = 0x94373a4919B3240D86eA41593D5eBa789FEF3848;
    address user = makeAddr("user");

    uint64 vaultVersion = 1;

    address symbioticVaultOwner = makeAddr("symbioticVaultOwner");
    address symbioticVaultAdmin = makeAddr("vaultAdmin");
    uint48 epochDuration = 8 hours;
    uint256 symbioticLimit = 100 ether;
    uint256 vaultLimit = 200 ether;
    address vaultProxyAdmin = makeAddr("vaultProxyAdmin");
    address vaultAdmin = makeAddr("vaultAdmin");

    function setUp() external {
        shrinkDefaultCollateralLimit(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL);
    }

    function _defaultDeploy()
        private
        returns (MellowSymbioticVault mellowSymbioticVault, ISymbioticVault symbioticVault)
    {
        mellowSymbioticVault = new MellowSymbioticVault("MellowSymbioticVault", 1);
        symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: symbioticVaultOwner,
                    vaultAdmin: symbioticVaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    isDepositLimit: false,
                    depositLimit: 0
                })
            )
        );

        IMellowSymbioticVault.InitParams memory initParams = IMellowSymbioticVault.InitParams({
            withdrawalQueue: address(
                new SymbioticWithdrawalQueue(address(mellowSymbioticVault), address(symbioticVault))
            ),
            limit: vaultLimit,
            symbioticCollateral: HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL,
            symbioticVault: address(symbioticVault),
            admin: makeAddr("vaultAdmin"),
            depositPause: false,
            withdrawalPause: false,
            depositWhitelist: false,
            name: "MellowSymbioticVault",
            symbol: "MSV"
        });
        mellowSymbioticVault.initialize(initParams);
    }

    function _extDeploy()
        private
        returns (MockMellowSymbioticVaultExt mellowSymbioticVault, ISymbioticVault symbioticVault)
    {
        mellowSymbioticVault = new MockMellowSymbioticVaultExt();
        symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: symbioticVaultOwner,
                    vaultAdmin: symbioticVaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    isDepositLimit: true,
                    depositLimit: 0
                })
            )
        );

        IMellowSymbioticVault.InitParams memory initParams = IMellowSymbioticVault.InitParams({
            withdrawalQueue: address(
                new SymbioticWithdrawalQueue(address(mellowSymbioticVault), address(symbioticVault))
            ),
            limit: vaultLimit,
            symbioticCollateral: HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL,
            symbioticVault: address(symbioticVault),
            admin: makeAddr("vaultAdmin"),
            depositPause: false,
            withdrawalPause: false,
            depositWhitelist: false,
            name: "MellowSymbioticVault",
            symbol: "MSV"
        });
        mellowSymbioticVault.initialize(initParams);
    }

    function testInitialize() external {
        MellowSymbioticVault c = new MellowSymbioticVault("MellowSymbioticVault", 1);

        ISymbioticVault symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: symbioticVaultOwner,
                    vaultAdmin: symbioticVaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    isDepositLimit: true,
                    depositLimit: symbioticLimit
                })
            )
        );

        IMellowSymbioticVault.InitParams memory initParams = IMellowSymbioticVault.InitParams({
            withdrawalQueue: makeAddr("withdrawalQueue"),
            limit: vaultLimit,
            symbioticCollateral: makeAddr("symbioticCollateral"),
            symbioticVault: address(symbioticVault),
            admin: makeAddr("vaultAdmin"),
            depositPause: false,
            withdrawalPause: false,
            depositWhitelist: false,
            name: "MellowSymbioticVault",
            symbol: "MSV"
        });

        vm.recordLogs();
        c.initialize(initParams);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 9);

        assertEq(logs[0].emitter, address(c));
        assertEq(logs[0].topics[0], keccak256("SymbioticCollateralSet(address,uint256)"));

        assertEq(logs[1].emitter, address(c));
        assertEq(logs[1].topics[0], keccak256("SymbioticVaultSet(address,uint256)"));

        assertEq(logs[2].emitter, address(c));
        assertEq(logs[2].topics[0], keccak256("WithdrawalQueueSet(address,uint256)"));

        assertEq(logs[3].emitter, address(c));
        assertEq(logs[3].topics[0], keccak256("RoleGranted(bytes32,address,address)"));

        assertEq(logs[4].emitter, address(c));
        assertEq(logs[4].topics[0], keccak256("LimitSet(uint256,uint256,address)"));

        assertEq(logs[5].emitter, address(c));
        assertEq(logs[5].topics[0], keccak256("DepositPauseSet(bool,uint256,address)"));

        assertEq(logs[6].emitter, address(c));
        assertEq(logs[6].topics[0], keccak256("WithdrawalPauseSet(bool,uint256,address)"));

        assertEq(logs[7].emitter, address(c));
        assertEq(logs[7].topics[0], keccak256("DepositWhitelistSet(bool,uint256,address)"));

        assertEq(logs[8].emitter, address(c));
        assertEq(logs[8].topics[0], keccak256("Initialized(uint64)"));

        // second initilization should fail
        vm.expectRevert();
        c.initialize(initParams);
    }

    function testSetFarm() external {
        (MellowSymbioticVault c, ISymbioticVault symbioticVault) = _defaultDeploy();
        address manager = makeAddr("manager");

        IMellowSymbioticVaultStorage.FarmData memory farmParams = IMellowSymbioticVaultStorage
            .FarmData({
            rewardToken: wsteth,
            symbioticFarm: makeAddr("symbioticFarm"),
            distributionFarm: makeAddr("distributionFarm"),
            curatorTreasury: makeAddr("curatorTreasury"),
            curatorFeeD6: 1e5
        });

        vm.startPrank(manager);

        // forbidden
        vm.expectRevert();
        c.setFarm(1, farmParams);

        vm.stopPrank();

        vm.startPrank(vaultAdmin);
        c.grantRole(SET_FARM_ROLE, manager);
        vm.stopPrank();

        vm.startPrank(manager);

        assertEq(c.symbioticFarmsContains(1), false);

        vm.recordLogs();
        c.setFarm(1, farmParams);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].emitter, address(c));
        assertEq(
            logs[0].topics[0],
            keccak256("FarmSet(uint256,(address,address,address,address,uint256),uint256)")
        );

        assertEq(c.symbioticFarmsContains(1), true);

        // no revert
        c.setFarm(1, farmParams);
        assertEq(c.symbioticFarmsContains(1), true);

        // no revert
        c.setFarm(2, farmParams);
        assertEq(c.symbioticFarmsContains(1), true);
        assertEq(c.symbioticFarmsContains(2), true);

        farmParams.rewardToken = address(0);
        // no revert
        c.setFarm(1, farmParams);

        assertEq(c.symbioticFarmsContains(1), false);
        assertEq(c.symbioticFarmsContains(2), true);
        // no revert
        c.setFarm(0, farmParams);

        assertEq(c.symbioticFarmsContains(1), false);
        assertEq(c.symbioticFarmsContains(2), true);

        // no revert
        c.setFarm(2, farmParams);

        assertEq(c.symbioticFarmsContains(1), false);
        assertEq(c.symbioticFarmsContains(2), false);

        IMellowSymbioticVaultStorage.FarmData memory invalidFarmParams =
        IMellowSymbioticVaultStorage.FarmData({
            rewardToken: address(c),
            symbioticFarm: makeAddr("symbioticFarm"),
            distributionFarm: makeAddr("distributionFarm"),
            curatorTreasury: makeAddr("curatorTreasury"),
            curatorFeeD6: 1e5
        });
        vm.expectRevert();
        c.setFarm(3, invalidFarmParams);

        invalidFarmParams = IMellowSymbioticVaultStorage.FarmData({
            rewardToken: address(symbioticVault),
            symbioticFarm: makeAddr("symbioticFarm"),
            distributionFarm: makeAddr("distributionFarm"),
            curatorTreasury: makeAddr("curatorTreasury"),
            curatorFeeD6: 1e5
        });
        vm.expectRevert();
        c.setFarm(3, invalidFarmParams);

        invalidFarmParams = IMellowSymbioticVaultStorage.FarmData({
            rewardToken: wsteth,
            symbioticFarm: makeAddr("symbioticFarm"),
            distributionFarm: makeAddr("distributionFarm"),
            curatorTreasury: makeAddr("curatorTreasury"),
            curatorFeeD6: 1e6 + 1
        });
        vm.expectRevert();
        c.setFarm(3, invalidFarmParams);

        vm.stopPrank();
    }

    function testTotalAssets() external {
        (MellowSymbioticVault c, ISymbioticVault symbioticVault) = _defaultDeploy();

        assertEq(c.totalAssets(), 0);
        deal(wsteth, address(c), 1 ether);
        assertEq(c.totalAssets(), 1 ether);
        deal(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL, address(c), 1 ether);
        assertEq(c.totalAssets(), 2 ether);

        c.pushIntoSymbiotic();

        assertEq(IERC20(wsteth).balanceOf(address(c)), 0 ether);
        assertEq(IERC20(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL).balanceOf(address(c)), 0 ether);
        assertEq(c.totalAssets(), 2 ether);

        deal(wsteth, address(c), 1 ether);
        assertEq(c.totalAssets(), 3 ether);
        deal(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL, address(c), 1 ether);
        assertEq(c.totalAssets(), 4 ether);
    }

    function testDeposit() external {
        (MellowSymbioticVault c, ISymbioticVault symbioticVault) = _defaultDeploy();

        address depositor = makeAddr("depositor");

        vm.startPrank(depositor);
        deal(wsteth, depositor, 1 ether);
        IERC20(wsteth).approve(address(c), type(uint256).max);

        vm.recordLogs();
        c.deposit(1 ether, depositor);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 9);

        assertEq(logs[3].emitter, address(c));
        assertEq(logs[3].topics[0], keccak256("Deposit(address,address,uint256,uint256)"));

        assertEq(logs[8].emitter, address(c));
        assertEq(logs[8].topics[0], keccak256("SymbioticPushed(address,uint256,uint256,uint256)"));

        assertEq(IERC20(wsteth).balanceOf(address(c)), 0, "Incorrect wsteth balance of the vault");

        assertEq(
            IERC20(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL).balanceOf(address(c)),
            0,
            "Incorrect wsteth DefaultCollateral balance of the vault"
        );

        assertEq(
            symbioticVault.activeBalanceOf(address(c)),
            1 ether,
            "Incorrect symbioticVault balance of the vault"
        );

        assertEq(c.balanceOf(depositor), 1 ether, "Incorrect balance of the depositor");

        vm.stopPrank();
    }

    function testMint() external {
        (MellowSymbioticVault c, ISymbioticVault symbioticVault) = _defaultDeploy();

        address depositor = makeAddr("depositor");

        vm.startPrank(depositor);
        deal(wsteth, depositor, 1 ether);
        IERC20(wsteth).approve(address(c), type(uint256).max);

        vm.recordLogs();
        c.mint(1 ether, depositor);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 9);

        assertEq(logs[3].emitter, address(c));
        assertEq(logs[3].topics[0], keccak256("Deposit(address,address,uint256,uint256)"));

        assertEq(logs[8].emitter, address(c));
        assertEq(logs[8].topics[0], keccak256("SymbioticPushed(address,uint256,uint256,uint256)"));

        vm.stopPrank();
    }

    function testWithdraw() external {
        // simple case
        {
            (MellowSymbioticVault c, ISymbioticVault symbioticVault) = _defaultDeploy();

            address depositor = makeAddr("depositor");

            vm.startPrank(depositor);
            deal(wsteth, depositor, 1 ether);
            IERC20(wsteth).approve(address(c), type(uint256).max);
            c.mint(1 ether, depositor);

            vm.recordLogs();
            c.withdraw(1 ether, depositor, depositor);

            Vm.Log[] memory logs = vm.getRecordedLogs();
            assertEq(logs.length, 4);

            assertEq(logs[1].emitter, address(c.withdrawalQueue()));
            assertEq(logs[1].topics[0], keccak256("WithdrawalRequested(address,uint256,uint256)"));

            assertEq(logs[3].emitter, address(c));
            assertEq(
                logs[3].topics[0], keccak256("Withdraw(address,address,address,uint256,uint256)")
            );

            assertEq(c.totalAssets(), 0);

            assertEq(IERC20(wsteth).balanceOf(depositor), 0 ether);
            assertEq(c.pendingAssetsOf(depositor), 1 ether);

            vm.stopPrank();
        }
        // case 1
        {
            MellowSymbioticVault singleton = new MellowSymbioticVault("MellowSymbioticVault", 1);
            MellowSymbioticVaultFactory factory =
                new MellowSymbioticVaultFactory(address(singleton));

            ISymbioticVault symbioticVault = ISymbioticVault(
                symbioticHelper.createNewSymbioticVault(
                    SymbioticHelper.CreationParams({
                        vaultOwner: symbioticVaultOwner,
                        vaultAdmin: symbioticVaultAdmin,
                        epochDuration: epochDuration,
                        asset: wsteth,
                        isDepositLimit: true,
                        depositLimit: symbioticLimit
                    })
                )
            );

            (IMellowSymbioticVault mellowSymbioticVault, /*IWithdrawalQueue withdrawalQueue*/ ) =
            factory.create(
                IMellowSymbioticVaultFactory.InitParams({
                    proxyAdmin: vaultProxyAdmin,
                    limit: vaultLimit,
                    symbioticCollateral: address(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL),
                    symbioticVault: address(symbioticVault),
                    admin: vaultAdmin,
                    depositPause: false,
                    withdrawalPause: false,
                    depositWhitelist: false,
                    name: "MellowSymbioticVault",
                    symbol: "MSV"
                })
            );

            address user = makeAddr("user");
            {
                vm.startPrank(user);
                uint256 amount = 200 ether;
                deal(wsteth, user, amount);
                IERC20(wsteth).approve(address(mellowSymbioticVault), amount);
                mellowSymbioticVault.deposit(amount, user);
                vm.stopPrank();
            }

            IDefaultCollateral c = IDefaultCollateral(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL);
            vm.prank(c.limitIncreaser());
            c.increaseLimit(50 ether);

            mellowSymbioticVault.pushIntoSymbiotic();

            {
                vm.startPrank(user);
                mellowSymbioticVault.withdraw(150 ether, user, user);
                vm.stopPrank();
            }
        }
        // case 2
        {
            MellowSymbioticVault singleton = new MellowSymbioticVault("MellowSymbioticVault", 1);
            MellowSymbioticVaultFactory factory =
                new MellowSymbioticVaultFactory(address(singleton));

            ISymbioticVault symbioticVault = ISymbioticVault(
                symbioticHelper.createNewSymbioticVault(
                    SymbioticHelper.CreationParams({
                        vaultOwner: symbioticVaultOwner,
                        vaultAdmin: symbioticVaultAdmin,
                        epochDuration: epochDuration,
                        asset: wsteth,
                        isDepositLimit: true,
                        depositLimit: 0
                    })
                )
            );

            (IMellowSymbioticVault mellowSymbioticVault, /*IWithdrawalQueue withdrawalQueue*/ ) =
            factory.create(
                IMellowSymbioticVaultFactory.InitParams({
                    proxyAdmin: vaultProxyAdmin,
                    limit: vaultLimit,
                    symbioticCollateral: address(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL),
                    symbioticVault: address(symbioticVault),
                    admin: vaultAdmin,
                    depositPause: false,
                    withdrawalPause: false,
                    depositWhitelist: false,
                    name: "MellowSymbioticVault",
                    symbol: "MSV"
                })
            );

            vm.startPrank(symbioticVaultAdmin);
            symbioticVault.setDepositWhitelist(true);
            symbioticVault.setDepositorWhitelistStatus(address(mellowSymbioticVault), true);
            vm.stopPrank();

            {
                vm.startPrank(user);
                uint256 amount = 200 ether;
                deal(wsteth, user, amount);
                IERC20(wsteth).approve(address(mellowSymbioticVault), amount);
                mellowSymbioticVault.deposit(amount, user);
                vm.stopPrank();
            }

            IDefaultCollateral c = IDefaultCollateral(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL);
            vm.prank(c.limitIncreaser());
            c.increaseLimit(50 ether);

            mellowSymbioticVault.pushIntoSymbiotic();

            {
                vm.startPrank(user);
                mellowSymbioticVault.withdraw(150 ether, user, user);
                vm.stopPrank();
            }
        }

        // case 3
        {
            MellowSymbioticVault singleton = new MellowSymbioticVault("MellowSymbioticVault", 1);
            MellowSymbioticVaultFactory factory =
                new MellowSymbioticVaultFactory(address(singleton));

            ISymbioticVault symbioticVault = ISymbioticVault(
                symbioticHelper.createNewSymbioticVault(
                    SymbioticHelper.CreationParams({
                        vaultOwner: symbioticVaultOwner,
                        vaultAdmin: symbioticVaultAdmin,
                        epochDuration: epochDuration,
                        asset: wsteth,
                        isDepositLimit: false,
                        depositLimit: 0
                    })
                )
            );

            (IMellowSymbioticVault mellowSymbioticVault, /*IWithdrawalQueue withdrawalQueue*/ ) =
            factory.create(
                IMellowSymbioticVaultFactory.InitParams({
                    proxyAdmin: vaultProxyAdmin,
                    limit: vaultLimit,
                    symbioticCollateral: address(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL),
                    symbioticVault: address(symbioticVault),
                    admin: vaultAdmin,
                    depositPause: false,
                    withdrawalPause: false,
                    depositWhitelist: false,
                    name: "MellowSymbioticVault",
                    symbol: "MSV"
                })
            );

            {
                vm.startPrank(user);
                uint256 amount = 10 ether;
                deal(wsteth, user, amount);
                IERC20(wsteth).approve(address(mellowSymbioticVault), amount);
                mellowSymbioticVault.deposit(amount, user);
                vm.stopPrank();
            }

            IDefaultCollateral c = IDefaultCollateral(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL);
            vm.prank(c.limitIncreaser());
            c.increaseLimit(50 ether);

            mellowSymbioticVault.pushIntoSymbiotic();

            {
                vm.startPrank(user);
                mellowSymbioticVault.withdraw(10 ether, user, user);
                vm.stopPrank();
            }
        }
    }

    function testRedeem() external {
        (MellowSymbioticVault c, ISymbioticVault symbioticVault) = _defaultDeploy();

        address depositor = makeAddr("depositor");

        vm.startPrank(depositor);
        deal(wsteth, depositor, 1 ether);
        IERC20(wsteth).approve(address(c), type(uint256).max);
        c.mint(1 ether, depositor);

        vm.recordLogs();
        c.redeem(1 ether, depositor, depositor);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 4);

        assertEq(logs[1].emitter, address(c.withdrawalQueue()));
        assertEq(logs[1].topics[0], keccak256("WithdrawalRequested(address,uint256,uint256)"));

        assertEq(logs[3].emitter, address(c));
        assertEq(logs[3].topics[0], keccak256("Withdraw(address,address,address,uint256,uint256)"));

        assertEq(c.totalAssets(), 0);

        assertEq(IERC20(wsteth).balanceOf(depositor), 0 ether);
        assertEq(c.pendingAssetsOf(depositor), 1 ether);
        assertEq(c.claimableAssetsOf(depositor), 0 ether);

        vm.stopPrank();
    }

    function testMellowSymbioticVaultInstantWithdrawal() external {
        MellowSymbioticVault singleton = new MellowSymbioticVault("MellowSymbioticVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        ISymbioticVault symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: symbioticVaultOwner,
                    vaultAdmin: symbioticVaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    isDepositLimit: true,
                    depositLimit: symbioticLimit
                })
            )
        );

        (IMellowSymbioticVault mellowSymbioticVault, IWithdrawalQueue withdrawalQueue) = factory
            .create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: vaultProxyAdmin,
                limit: vaultLimit,
                symbioticCollateral: address(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL),
                symbioticVault: address(symbioticVault),
                admin: vaultAdmin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        vm.expectRevert();
        mellowSymbioticVault.initialize(
            IMellowSymbioticVault.InitParams({
                withdrawalQueue: address(withdrawalQueue),
                limit: vaultLimit,
                symbioticCollateral: address(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL),
                symbioticVault: address(symbioticVault),
                admin: vaultAdmin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        vm.startPrank(user);

        deal(wsteth, user, vaultLimit);
        IERC20(wsteth).approve(address(mellowSymbioticVault), vaultLimit);
        uint256 lpAmount = mellowSymbioticVault.deposit(vaultLimit, user, address(1));
        assertEq(lpAmount, vaultLimit);

        assertEq(
            IERC20(wsteth).balanceOf(address(mellowSymbioticVault)),
            vaultLimit / 2,
            "Incorrect wsteth balance of the vault"
        );
        assertEq(
            IERC20(address(symbioticVault)).balanceOf(address(mellowSymbioticVault)),
            vaultLimit / 2,
            "Incorrect symbioticVault balance of the vault"
        );

        mellowSymbioticVault.withdraw(vaultLimit / 2, user, user);

        assertEq(
            IERC20(wsteth).balanceOf(user), vaultLimit / 2, "Incorrect wsteth balance for user"
        );

        assertEq(
            IERC20(wsteth).balanceOf(address(mellowSymbioticVault)),
            0,
            "Incorrect wsteth balance of the vault"
        );

        assertEq(
            IERC20(address(symbioticVault)).balanceOf(address(mellowSymbioticVault)),
            vaultLimit / 2,
            "Incorrect symbioticVault balance of the vault"
        );

        assertEq(
            mellowSymbioticVault.pendingAssetsOf(user), 0, "Incorrect pending assets of the user"
        );

        assertEq(
            mellowSymbioticVault.claimableAssetsOf(user), 0, "Incorrect pending assets of the user"
        );

        vm.stopPrank();
    }

    function testMellowSymbioticVaultPausedWithdrawal() external {
        MellowSymbioticVault singleton = new MellowSymbioticVault("MellowSymbioticVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        ISymbioticVault symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: symbioticVaultOwner,
                    vaultAdmin: symbioticVaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    isDepositLimit: true,
                    depositLimit: symbioticLimit
                })
            )
        );

        (IMellowSymbioticVault mellowSymbioticVault, /*IWithdrawalQueue withdrawalQueue*/ ) =
        factory.create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: vaultProxyAdmin,
                limit: vaultLimit,
                symbioticCollateral: address(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL),
                symbioticVault: address(symbioticVault),
                admin: vaultAdmin,
                depositPause: false,
                withdrawalPause: true,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        vm.startPrank(user);

        deal(wsteth, user, vaultLimit);
        IERC20(wsteth).approve(address(mellowSymbioticVault), vaultLimit);
        uint256 lpAmount = mellowSymbioticVault.deposit(vaultLimit, user);
        assertEq(lpAmount, vaultLimit);

        assertEq(
            IERC20(wsteth).balanceOf(address(mellowSymbioticVault)),
            vaultLimit / 2,
            "Incorrect wsteth balance of the vault"
        );
        assertEq(
            IERC20(address(symbioticVault)).balanceOf(address(mellowSymbioticVault)),
            vaultLimit / 2,
            "Incorrect symbioticVault balance of the vault"
        );

        vm.expectRevert();
        mellowSymbioticVault.withdraw(vaultLimit / 2, user, user);

        vm.stopPrank();
    }

    function testMellowSymbioticVaultInstantAndPendingWithdrawal() external {
        MellowSymbioticVault singleton = new MellowSymbioticVault("MellowSymbioticVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        ISymbioticVault symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: symbioticVaultOwner,
                    vaultAdmin: symbioticVaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    isDepositLimit: true,
                    depositLimit: symbioticLimit
                })
            )
        );

        (IMellowSymbioticVault mellowSymbioticVault, IWithdrawalQueue withdrawalQueue) = factory
            .create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: vaultProxyAdmin,
                limit: vaultLimit,
                symbioticCollateral: address(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL),
                symbioticVault: address(symbioticVault),
                admin: vaultAdmin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        vm.startPrank(user);

        deal(wsteth, user, vaultLimit);
        IERC20(wsteth).approve(address(mellowSymbioticVault), vaultLimit);
        uint256 lpAmount = mellowSymbioticVault.deposit(vaultLimit, user);
        assertEq(lpAmount, vaultLimit);

        (
            uint256 accountAssets,
            uint256 accountInstantAssets,
            uint256 accountShares,
            uint256 accountInstantShares
        ) = mellowSymbioticVault.getBalances(user);

        assertEq(accountAssets, vaultLimit, "Incorrect assets");
        assertEq(accountInstantAssets, vaultLimit / 2, "Incorrect instant assets");
        assertEq(accountShares, vaultLimit, "Incorrect shares");
        assertEq(accountInstantShares, vaultLimit / 2, "Incorrect instant shares");

        assertEq(
            IERC20(wsteth).balanceOf(address(mellowSymbioticVault)),
            vaultLimit / 2,
            "Incorrect wsteth balance of the vault"
        );
        assertEq(
            IERC20(address(symbioticVault)).balanceOf(address(mellowSymbioticVault)),
            vaultLimit / 2,
            "Incorrect symbioticVault balance of the vault"
        );

        mellowSymbioticVault.withdraw(vaultLimit, user, user);

        assertEq(
            IERC20(wsteth).balanceOf(user), vaultLimit / 2, "Incorrect wsteth balance for user"
        );

        assertEq(
            IERC20(wsteth).balanceOf(address(mellowSymbioticVault)),
            0,
            "Incorrect wsteth balance of the vault"
        );

        assertEq(
            IERC20(address(symbioticVault)).balanceOf(address(mellowSymbioticVault)),
            0,
            "Incorrect symbioticVault balance of the vault"
        );

        assertEq(
            IERC20(address(symbioticVault)).balanceOf(address(withdrawalQueue)),
            vaultLimit / 2,
            "Incorrect symbioticVault balance of the vault"
        );

        assertEq(
            mellowSymbioticVault.pendingAssetsOf(user),
            vaultLimit / 2,
            "Incorrect pending assets of the user"
        );

        assertEq(
            mellowSymbioticVault.claimableAssetsOf(user), 0, "Incorrect pending assets of the user"
        );

        skip(epochDuration * 2);

        assertEq(
            mellowSymbioticVault.pendingAssetsOf(user), 0, "Incorrect pending assets of the user"
        );

        assertEq(
            mellowSymbioticVault.claimableAssetsOf(user),
            vaultLimit / 2,
            "Incorrect pending assets of the user"
        );

        vm.stopPrank();
    }

    function testMellowSymbioticVaultInstantAndPendingWithdrawalOnBehalf() external {
        MellowSymbioticVault singleton = new MellowSymbioticVault("MellowSymbioticVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        ISymbioticVault symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: symbioticVaultOwner,
                    vaultAdmin: symbioticVaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    isDepositLimit: true,
                    depositLimit: symbioticLimit
                })
            )
        );

        (IMellowSymbioticVault mellowSymbioticVault, IWithdrawalQueue withdrawalQueue) = factory
            .create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: vaultProxyAdmin,
                limit: vaultLimit,
                symbioticCollateral: address(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL),
                symbioticVault: address(symbioticVault),
                admin: vaultAdmin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        vm.startPrank(user);

        deal(wsteth, user, vaultLimit);
        IERC20(wsteth).approve(address(mellowSymbioticVault), vaultLimit);
        uint256 lpAmount = mellowSymbioticVault.deposit(vaultLimit, user);
        assertEq(lpAmount, vaultLimit);

        assertEq(
            IERC20(wsteth).balanceOf(address(mellowSymbioticVault)),
            vaultLimit / 2,
            "Incorrect wsteth balance of the vault"
        );
        assertEq(
            IERC20(address(symbioticVault)).balanceOf(address(mellowSymbioticVault)),
            vaultLimit / 2,
            "Incorrect symbioticVault balance of the vault"
        );

        address anotherUser = makeAddr("anotherUser");
        mellowSymbioticVault.approve(anotherUser, type(uint256).max);

        vm.stopPrank();

        vm.startPrank(anotherUser);

        mellowSymbioticVault.withdraw(vaultLimit, anotherUser, user);

        assertEq(
            IERC20(wsteth).balanceOf(anotherUser),
            vaultLimit / 2,
            "Incorrect wsteth balance for anotherUser"
        );

        assertEq(
            IERC20(wsteth).balanceOf(address(mellowSymbioticVault)),
            0,
            "Incorrect wsteth balance of the vault"
        );

        assertEq(
            IERC20(address(symbioticVault)).balanceOf(address(mellowSymbioticVault)),
            0,
            "Incorrect symbioticVault balance of the vault"
        );

        assertEq(
            IERC20(address(symbioticVault)).balanceOf(address(withdrawalQueue)),
            vaultLimit / 2,
            "Incorrect symbioticVault balance of the vault"
        );

        assertEq(
            mellowSymbioticVault.pendingAssetsOf(anotherUser),
            vaultLimit / 2,
            "Incorrect pending assets of the user"
        );

        assertEq(
            mellowSymbioticVault.claimableAssetsOf(anotherUser),
            0,
            "Incorrect pending assets of the anotherUser"
        );

        skip(epochDuration * 2);

        assertEq(
            mellowSymbioticVault.pendingAssetsOf(anotherUser),
            0,
            "Incorrect pending assets of the anotherUser"
        );

        assertEq(
            mellowSymbioticVault.claimableAssetsOf(anotherUser),
            vaultLimit / 2,
            "Incorrect pending assets of the user"
        );

        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert();
        mellowSymbioticVault.claim(anotherUser, user, type(uint256).max);
        vm.stopPrank();
    }

    function testPushIntoSymbiotic() external {}

    function testPushIntoSymbioticNothingToPush() external {
        MellowSymbioticVault singleton = new MellowSymbioticVault("MellowSymbioticVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        ISymbioticVault symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: symbioticVaultOwner,
                    vaultAdmin: symbioticVaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    isDepositLimit: true,
                    depositLimit: symbioticLimit
                })
            )
        );

        (IMellowSymbioticVault mellowSymbioticVault, /*IWithdrawalQueue withdrawalQueue*/ ) =
        factory.create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: vaultProxyAdmin,
                limit: vaultLimit,
                symbioticCollateral: address(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL),
                symbioticVault: address(symbioticVault),
                admin: vaultAdmin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        vm.startPrank(user);

        deal(wsteth, user, vaultLimit);
        IERC20(wsteth).approve(address(mellowSymbioticVault), vaultLimit);
        uint256 lpAmount = mellowSymbioticVault.deposit(vaultLimit, user);
        vm.stopPrank();
    }

    function testPushIntoSymbioticMockSymbioticVault() external {
        MellowSymbioticVault singleton = new MellowSymbioticVault("MellowSymbioticVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        MockMellowSymbioticVault symbioticVault = new MockMellowSymbioticVault();

        (IMellowSymbioticVault mellowSymbioticVault, /*IWithdrawalQueue withdrawalQueue*/ ) =
        factory.create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: vaultProxyAdmin,
                limit: vaultLimit,
                symbioticCollateral: address(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL),
                symbioticVault: address(symbioticVault),
                admin: vaultAdmin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        vm.startPrank(user);

        deal(wsteth, user, vaultLimit);
        IERC20(wsteth).approve(address(mellowSymbioticVault), vaultLimit);

        symbioticVault.setLimit(true, symbioticLimit);

        uint256 lpAmount = mellowSymbioticVault.deposit(vaultLimit, user);
        vm.stopPrank();

        symbioticVault.setLimit(false, 0);
        symbioticVault.setLoss();

        assertEq(lpAmount, vaultLimit);
        mellowSymbioticVault.pushIntoSymbiotic();
    }

    function testPushRewards() external {
        MellowSymbioticVault singleton = new MellowSymbioticVault("MellowSymbioticVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        ISymbioticVault symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: symbioticVaultOwner,
                    vaultAdmin: symbioticVaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    isDepositLimit: true,
                    depositLimit: symbioticLimit
                })
            )
        );

        (IMellowSymbioticVault mellowSymbioticVault, /*IWithdrawalQueue withdrawalQueue*/ ) =
        factory.create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: vaultProxyAdmin,
                limit: vaultLimit,
                symbioticCollateral: address(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL),
                symbioticVault: address(symbioticVault),
                admin: vaultAdmin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        vm.startPrank(vaultAdmin);
        MellowSymbioticVault(address(mellowSymbioticVault)).grantRole(
            keccak256("SET_FARM_ROLE"), vaultAdmin
        );

        address mockSymbioticFarm = address(new MockSymbioticFarm());
        address mockDistributionFarm = makeAddr("mockDistributionFarm");
        address curatorTreasury = makeAddr("curatorTreasury");
        uint64 curatorFeeD6 = 1e5; // 10%

        vm.expectRevert();
        mellowSymbioticVault.setFarm(
            1,
            IMellowSymbioticVaultStorage.FarmData({
                rewardToken: address(mellowSymbioticVault),
                symbioticFarm: mockSymbioticFarm,
                distributionFarm: mockDistributionFarm,
                curatorTreasury: curatorTreasury,
                curatorFeeD6: curatorFeeD6
            })
        );

        assertEq(
            mellowSymbioticVault.totalAssets(),
            0,
            "Incorrect total assets of the mellowSymbioticVault"
        );

        vm.expectRevert();
        mellowSymbioticVault.setFarm(
            1,
            IMellowSymbioticVaultStorage.FarmData({
                rewardToken: address(symbioticVault),
                symbioticFarm: mockSymbioticFarm,
                distributionFarm: mockDistributionFarm,
                curatorTreasury: curatorTreasury,
                curatorFeeD6: curatorFeeD6
            })
        );

        vm.expectRevert();
        mellowSymbioticVault.setFarm(
            1,
            IMellowSymbioticVaultStorage.FarmData({
                rewardToken: wsteth,
                symbioticFarm: mockSymbioticFarm,
                distributionFarm: mockDistributionFarm,
                curatorTreasury: curatorTreasury,
                curatorFeeD6: 1e6 + 1
            })
        );

        mellowSymbioticVault.setFarm(
            1,
            IMellowSymbioticVaultStorage.FarmData({
                rewardToken: wsteth,
                symbioticFarm: mockSymbioticFarm,
                distributionFarm: mockDistributionFarm,
                curatorTreasury: curatorTreasury,
                curatorFeeD6: curatorFeeD6
            })
        );

        vm.stopPrank();

        deal(wsteth, mockSymbioticFarm, 10 ether);

        mellowSymbioticVault.pushRewards(1, new bytes(0));

        assertEq(
            IERC20(wsteth).balanceOf(mockDistributionFarm),
            9 ether,
            "Incorrect balance of the mockDistributionFarm"
        );

        assertEq(
            IERC20(wsteth).balanceOf(curatorTreasury),
            1 ether,
            "Incorrect balance of the curatorTreasury"
        );

        assertEq(
            IERC20(wsteth).balanceOf(mockSymbioticFarm),
            0 ether,
            "Incorrect balance of the mockSymbioticFarm"
        );

        mellowSymbioticVault.pushRewards(1, new bytes(0));
        assertEq(
            IERC20(wsteth).balanceOf(mockDistributionFarm),
            9 ether,
            "Incorrect balance of the mockDistributionFarm"
        );

        assertEq(
            IERC20(wsteth).balanceOf(curatorTreasury),
            1 ether,
            "Incorrect balance of the curatorTreasury"
        );

        assertEq(
            IERC20(wsteth).balanceOf(mockSymbioticFarm),
            0 ether,
            "Incorrect balance of the mockSymbioticFarm"
        );

        vm.expectRevert();
        mellowSymbioticVault.pushRewards(0, new bytes(0));
    }

    function testDepositExt000() external {
        (MockMellowSymbioticVaultExt vault, ISymbioticVault symbioticVault) = _extDeploy();

        {
            vm.startPrank(user);
            uint256 amount = 10 ether;
            deal(wsteth, user, amount);
            IERC20(wsteth).approve(address(vault), amount);
            vault.deposit(amount, user);
            vm.stopPrank();
        }

        IDefaultCollateral c = IDefaultCollateral(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL);
        assertEq(c.limit(), c.totalSupply());

        (uint256 collateralWithdrawal, uint256 collateralDeposit, uint256 vaultDeposit) =
            vault.calculatePushAmounts();

        assertEq(collateralWithdrawal, 0);
        assertEq(collateralDeposit, 0);
        assertEq(vaultDeposit, 0);

        vault.pushIntoSymbiotic();
    }

    function testDepositExt010() external {
        (MockMellowSymbioticVaultExt vault, ISymbioticVault symbioticVault) = _extDeploy();

        {
            vm.startPrank(user);
            uint256 amount = 10 ether;
            deal(wsteth, user, amount);
            IERC20(wsteth).approve(address(vault), amount);
            vault.deposit(amount, user);
            vm.stopPrank();
        }

        IDefaultCollateral c = IDefaultCollateral(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL);
        assertEq(c.limit(), c.totalSupply());

        vm.prank(c.limitIncreaser());
        c.increaseLimit(50 ether);

        (uint256 collateralWithdrawal, uint256 collateralDeposit, uint256 vaultDeposit) =
            vault.calculatePushAmounts();

        assertEq(collateralWithdrawal, 0);
        assertEq(collateralDeposit, 10 ether);
        assertEq(vaultDeposit, 0);

        vault.pushIntoSymbiotic();
    }

    function testDepositExt001() external {
        (MockMellowSymbioticVaultExt vault, ISymbioticVault symbioticVault) = _extDeploy();

        {
            vm.startPrank(user);
            uint256 amount = 10 ether;
            deal(wsteth, user, amount);
            IERC20(wsteth).approve(address(vault), amount);
            vault.deposit(amount, user);
            vm.stopPrank();
        }

        vm.prank(symbioticVaultAdmin);
        symbioticVault.setIsDepositLimit(false);

        IDefaultCollateral c = IDefaultCollateral(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL);
        assertEq(c.limit(), c.totalSupply());

        (uint256 collateralWithdrawal, uint256 collateralDeposit, uint256 vaultDeposit) =
            vault.calculatePushAmounts();

        assertEq(collateralWithdrawal, 0);
        assertEq(collateralDeposit, 0);
        assertEq(vaultDeposit, 10 ether);

        vault.pushIntoSymbiotic();
    }

    function testDepositExt101() external {
        (MockMellowSymbioticVaultExt vault, ISymbioticVault symbioticVault) = _extDeploy();

        IDefaultCollateral c = IDefaultCollateral(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL);
        assertEq(c.limit(), c.totalSupply());

        vm.prank(c.limitIncreaser());
        c.increaseLimit(50 ether);

        {
            vm.startPrank(user);
            uint256 amount = 10 ether;
            deal(wsteth, user, amount);
            IERC20(wsteth).approve(address(vault), amount);
            vault.deposit(amount, user);
            vm.stopPrank();
        }

        vm.prank(symbioticVaultAdmin);
        symbioticVault.setIsDepositLimit(false);

        (uint256 collateralWithdrawal, uint256 collateralDeposit, uint256 vaultDeposit) =
            vault.calculatePushAmounts();

        assertEq(collateralWithdrawal, 10 ether);
        assertEq(collateralDeposit, 0);
        assertEq(vaultDeposit, 10 ether);

        vault.pushIntoSymbiotic();
    }

    function testDepositExt011() external {
        (MockMellowSymbioticVaultExt vault, ISymbioticVault symbioticVault) = _extDeploy();

        IDefaultCollateral c = IDefaultCollateral(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL);
        assertEq(c.limit(), c.totalSupply());

        {
            vm.startPrank(user);
            uint256 amount = 10 ether;
            deal(wsteth, user, amount);
            IERC20(wsteth).approve(address(vault), amount);
            vault.deposit(amount, user);
            vm.stopPrank();
        }

        vm.prank(c.limitIncreaser());
        c.increaseLimit(5 ether);
        vm.prank(symbioticVaultAdmin);
        symbioticVault.setDepositLimit(5 ether);

        (uint256 collateralWithdrawal, uint256 collateralDeposit, uint256 vaultDeposit) =
            vault.calculatePushAmounts();

        assertEq(collateralWithdrawal, 0 ether);
        assertEq(collateralDeposit, 5 ether);
        assertEq(vaultDeposit, 5 ether);

        vault.pushIntoSymbiotic();
    }
}
