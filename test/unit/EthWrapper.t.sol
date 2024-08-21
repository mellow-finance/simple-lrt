// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

contract Unit is BaseTest {
    address wsteth = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;
    address steth = 0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034;
    address weth = 0x94373a4919B3240D86eA41593D5eBa789FEF3848;

    function testConstructor() external {
        EthWrapper ethWrapper = new EthWrapper(weth, wsteth, steth);

        assertEq(ethWrapper.WETH(), weth);
        assertEq(ethWrapper.wstETH(), wsteth);
        assertEq(ethWrapper.stETH(), steth);
    }

    function testEthDeposit() external {
        {
            EthWrapper ethWrapper = new EthWrapper(weth, wsteth, steth);

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = wsteth;
            vault.initialize(
                IIdleVault.InitParams({
                    asset: token,
                    limit: 100 ether,
                    depositPause: false,
                    withdrawalPause: false,
                    depositWhitelist: false,
                    admin: makeAddr("admin"),
                    name: "IdleVault",
                    symbol: "IDLE"
                })
            );

            vm.startPrank(user);

            uint256 amount = 0.1 ether;
            deal(user, amount);

            address eth = ethWrapper.ETH();

            vm.expectRevert();
            ethWrapper.deposit{value: amount}(eth, 0, address(vault), user, address(0));

            vm.expectRevert();
            ethWrapper.deposit{value: amount}(address(1), 1, address(vault), user, address(0));

            vm.expectRevert();
            ethWrapper.deposit{value: amount}(eth, amount - 1, address(vault), user, address(0));

            vm.expectRevert();
            ethWrapper.deposit{value: amount}(weth, amount, address(vault), user, address(0));

            ethWrapper.deposit{value: amount}(eth, amount, address(vault), user, address(0));

            assertApproxEqAbs(
                vault.balanceOf(user), IWSTETH(wsteth).getWstETHByStETH(amount), 1 wei
            );

            vm.stopPrank();
        }

        {
            EthWrapper ethWrapper = new EthWrapper(weth, wsteth, steth);

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = wsteth;
            vault.initialize(
                IIdleVault.InitParams({
                    asset: token,
                    limit: 100 ether,
                    depositPause: false,
                    withdrawalPause: false,
                    depositWhitelist: false,
                    admin: makeAddr("admin"),
                    name: "IdleVault",
                    symbol: "IDLE"
                })
            );

            vm.startPrank(user);

            uint256 amount = 1e10 ether;
            address eth = ethWrapper.ETH();
            deal(user, amount);

            vm.expectRevert();
            ethWrapper.deposit{value: amount}(eth, amount, address(vault), user, address(0));

            vm.stopPrank();
        }
    }

    function testWethDeposit() external {
        {
            EthWrapper ethWrapper = new EthWrapper(weth, wsteth, steth);

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = wsteth;
            vault.initialize(
                IIdleVault.InitParams({
                    asset: token,
                    limit: 100 ether,
                    depositPause: false,
                    withdrawalPause: false,
                    depositWhitelist: false,
                    admin: makeAddr("admin"),
                    name: "IdleVault",
                    symbol: "IDLE"
                })
            );

            vm.startPrank(user);

            uint256 amount = 0.1 ether;
            deal(weth, user, amount);

            IERC20(weth).approve(address(ethWrapper), amount);
            ethWrapper.deposit(weth, amount, address(vault), user, address(0));

            assertApproxEqAbs(
                vault.balanceOf(user), IWSTETH(wsteth).getWstETHByStETH(amount), 1 wei
            );

            vm.stopPrank();
        }

        {
            EthWrapper ethWrapper = new EthWrapper(weth, wsteth, steth);

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = wsteth;
            vault.initialize(
                IIdleVault.InitParams({
                    asset: token,
                    limit: 100 ether,
                    depositPause: false,
                    withdrawalPause: false,
                    depositWhitelist: false,
                    admin: makeAddr("admin"),
                    name: "IdleVault",
                    symbol: "IDLE"
                })
            );

            vm.startPrank(user);

            uint256 amount = 1e10 ether;
            deal(weth, user, amount);

            IERC20(weth).approve(address(ethWrapper), amount);
            vm.expectRevert();
            ethWrapper.deposit(weth, amount, address(vault), user, address(0));

            vm.stopPrank();
        }

        {
            EthWrapper oldWrapper = new EthWrapper(weth, wsteth, steth);
            EthWrapper ethWrapper = new EthWrapper(weth, address(oldWrapper), steth);

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = wsteth;
            vault.initialize(
                IIdleVault.InitParams({
                    asset: token,
                    limit: 100 ether,
                    depositPause: false,
                    withdrawalPause: false,
                    depositWhitelist: false,
                    admin: makeAddr("admin"),
                    name: "IdleVault",
                    symbol: "IDLE"
                })
            );

            vm.startPrank(user);

            uint256 amount = 1 ether;
            deal(weth, user, amount);

            IERC20(weth).approve(address(ethWrapper), amount);
            vm.expectRevert();
            ethWrapper.deposit(weth, amount, address(vault), user, address(0));

            vm.stopPrank();
        }

        {
            EthWrapper ethWrapper = new EthWrapper(address(0), wsteth, steth);

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = wsteth;
            vault.initialize(
                IIdleVault.InitParams({
                    asset: token,
                    limit: 100 ether,
                    depositPause: false,
                    withdrawalPause: false,
                    depositWhitelist: false,
                    admin: makeAddr("admin"),
                    name: "IdleVault",
                    symbol: "IDLE"
                })
            );

            vm.startPrank(user);

            uint256 amount = 0.1 ether;
            deal(weth, user, amount);

            IERC20(weth).approve(address(ethWrapper), amount);

            vm.expectRevert();
            ethWrapper.deposit(address(0), amount, address(vault), user, address(0));
            vm.stopPrank();
        }
    }

    function testWstethDeposit() external {
        EthWrapper ethWrapper = new EthWrapper(weth, wsteth, steth);

        address user = makeAddr("user");

        IdleVault vault = new IdleVault();
        address token = wsteth;
        vault.initialize(
            IIdleVault.InitParams({
                asset: token,
                limit: 100 ether,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                admin: makeAddr("admin"),
                name: "IdleVault",
                symbol: "IDLE"
            })
        );

        vm.startPrank(user);

        uint256 amount = 0.1 ether;
        deal(wsteth, user, amount);

        IERC20(wsteth).approve(address(ethWrapper), amount);
        ethWrapper.deposit(wsteth, amount, address(vault), user, address(0));

        assertApproxEqAbs(vault.balanceOf(user), amount, 1 wei);

        vm.stopPrank();
    }

    function testStethDeposit() external {
        {
            EthWrapper ethWrapper = new EthWrapper(weth, wsteth, steth);

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = wsteth;
            vault.initialize(
                IIdleVault.InitParams({
                    asset: token,
                    limit: 100 ether,
                    depositPause: false,
                    withdrawalPause: false,
                    depositWhitelist: false,
                    admin: makeAddr("admin"),
                    name: "IdleVault",
                    symbol: "IDLE"
                })
            );

            vm.startPrank(user);

            uint256 amount = 0.1 ether;
            deal(user, amount);

            ISTETH(steth).submit{value: amount}(address(0));
            IERC20(steth).approve(address(address(ethWrapper)), amount);

            ethWrapper.deposit(steth, amount, address(vault), user, address(0));

            assertApproxEqAbs(
                vault.balanceOf(user), IWSTETH(wsteth).getWstETHByStETH(amount), 1 wei
            );

            vm.stopPrank();
        }

        {
            EthWrapper ethWrapper = new EthWrapper(weth, steth, steth);

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = wsteth;
            vault.initialize(
                IIdleVault.InitParams({
                    asset: token,
                    limit: 100 ether,
                    depositPause: false,
                    withdrawalPause: false,
                    depositWhitelist: false,
                    admin: makeAddr("admin"),
                    name: "IdleVault",
                    symbol: "IDLE"
                })
            );

            vm.startPrank(user);

            uint256 amount = 0.1 ether;
            deal(user, amount);

            ISTETH(steth).submit{value: amount}(address(0));
            IERC20(steth).approve(address(address(ethWrapper)), amount);

            vm.expectRevert();
            ethWrapper.deposit(steth, amount, address(vault), user, address(0));

            vm.stopPrank();
        }
    }
}
