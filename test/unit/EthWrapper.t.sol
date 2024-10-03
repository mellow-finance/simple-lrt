// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

contract Unit is BaseTest {
    function testConstructor() external {
        {
            EthWrapper ethWrapper = new EthWrapper(HOLESKY_WETH, HOLESKY_WSTETH, HOLESKY_STETH);
            assertEq(ethWrapper.WETH(), HOLESKY_WETH);
            assertEq(ethWrapper.wstETH(), HOLESKY_WSTETH);
            assertEq(ethWrapper.stETH(), HOLESKY_STETH);
        }

        // zero params
        {
            EthWrapper ethWrapper = new EthWrapper(address(0), address(0), address(0));
            assertEq(ethWrapper.WETH(), address(0));
            assertEq(ethWrapper.wstETH(), address(0));
            assertEq(ethWrapper.stETH(), address(0));
        }
    }

    function testEthDeposit() external {
        {
            EthWrapper ethWrapper = new EthWrapper(HOLESKY_WETH, HOLESKY_WSTETH, HOLESKY_STETH);

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = HOLESKY_WSTETH;
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
            ethWrapper.deposit{value: amount}(
                HOLESKY_WETH, amount, address(vault), user, address(0)
            );

            ethWrapper.deposit{value: amount}(eth, amount, address(vault), user, address(0));

            assertApproxEqAbs(
                vault.balanceOf(user), IWSTETH(HOLESKY_WSTETH).getWstETHByStETH(amount), 1 wei
            );

            vm.stopPrank();
        }

        {
            EthWrapper ethWrapper = new EthWrapper(HOLESKY_WETH, HOLESKY_WSTETH, HOLESKY_STETH);

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = HOLESKY_WSTETH;
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
            EthWrapper ethWrapper = new EthWrapper(HOLESKY_WETH, HOLESKY_WSTETH, HOLESKY_STETH);

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = HOLESKY_WSTETH;
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
            deal(HOLESKY_WETH, user, amount);

            IERC20(HOLESKY_WETH).approve(address(ethWrapper), amount);
            ethWrapper.deposit(HOLESKY_WETH, amount, address(vault), user, address(0));

            assertApproxEqAbs(
                vault.balanceOf(user), IWSTETH(HOLESKY_WSTETH).getWstETHByStETH(amount), 1 wei
            );

            vm.stopPrank();
        }

        {
            EthWrapper ethWrapper = new EthWrapper(HOLESKY_WETH, HOLESKY_WSTETH, HOLESKY_STETH);

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = HOLESKY_WSTETH;
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
            deal(HOLESKY_WETH, user, amount);

            IERC20(HOLESKY_WETH).approve(address(ethWrapper), amount);
            vm.expectRevert();
            ethWrapper.deposit(HOLESKY_WETH, amount, address(vault), user, address(0));

            vm.stopPrank();
        }

        {
            EthWrapper oldWrapper = new EthWrapper(HOLESKY_WETH, HOLESKY_WSTETH, HOLESKY_STETH);
            EthWrapper ethWrapper = new EthWrapper(HOLESKY_WETH, address(oldWrapper), HOLESKY_STETH);

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = HOLESKY_WSTETH;
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
            deal(HOLESKY_WETH, user, amount);

            IERC20(HOLESKY_WETH).approve(address(ethWrapper), amount);
            vm.expectRevert();
            ethWrapper.deposit(HOLESKY_WETH, amount, address(vault), user, address(0));

            vm.stopPrank();
        }

        {
            EthWrapper ethWrapper = new EthWrapper(address(0), HOLESKY_WSTETH, HOLESKY_STETH);

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = HOLESKY_WSTETH;
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
            deal(HOLESKY_WETH, user, amount);

            IERC20(HOLESKY_WETH).approve(address(ethWrapper), amount);

            vm.expectRevert();
            ethWrapper.deposit(address(0), amount, address(vault), user, address(0));
            vm.stopPrank();
        }
    }

    function testWstethDeposit() external {
        EthWrapper ethWrapper = new EthWrapper(HOLESKY_WETH, HOLESKY_WSTETH, HOLESKY_STETH);

        address user = makeAddr("user");

        IdleVault vault = new IdleVault();
        address token = HOLESKY_WSTETH;
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
        deal(HOLESKY_WSTETH, user, amount);

        IERC20(HOLESKY_WSTETH).approve(address(ethWrapper), amount);
        ethWrapper.deposit(HOLESKY_WSTETH, amount, address(vault), user, address(0));

        assertApproxEqAbs(vault.balanceOf(user), amount, 1 wei);

        vm.stopPrank();
    }

    function testStethDeposit() external {
        {
            EthWrapper ethWrapper = new EthWrapper(HOLESKY_WETH, HOLESKY_WSTETH, HOLESKY_STETH);

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = HOLESKY_WSTETH;
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

            ISTETH(HOLESKY_STETH).submit{value: amount}(address(0));
            IERC20(HOLESKY_STETH).approve(address(address(ethWrapper)), amount);

            ethWrapper.deposit(HOLESKY_STETH, amount, address(vault), user, address(0));

            assertApproxEqAbs(
                vault.balanceOf(user), IWSTETH(HOLESKY_WSTETH).getWstETHByStETH(amount), 1 wei
            );

            vm.stopPrank();
        }

        {
            EthWrapper ethWrapper = new EthWrapper(HOLESKY_WETH, HOLESKY_STETH, HOLESKY_STETH);

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = HOLESKY_WSTETH;
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

            ISTETH(HOLESKY_STETH).submit{value: amount}(address(0));
            IERC20(HOLESKY_STETH).approve(address(address(ethWrapper)), amount);

            vm.expectRevert();
            ethWrapper.deposit(HOLESKY_STETH, amount, address(vault), user, address(0));

            vm.stopPrank();
        }
    }
}
