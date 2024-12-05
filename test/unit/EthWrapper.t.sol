// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/WhitelistedEthWrapper.sol";
import "../BaseTest.sol";

contract Unit is BaseTest {
    function testConstructor() external {
        {
            EthWrapper ethWrapper =
                new EthWrapper(Constants.WETH(), Constants.WSTETH(), Constants.STETH());
            assertEq(ethWrapper.WETH(), Constants.WETH());
            assertEq(ethWrapper.wstETH(), Constants.WSTETH());
            assertEq(ethWrapper.stETH(), Constants.STETH());
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
            EthWrapper ethWrapper =
                new EthWrapper(Constants.WETH(), Constants.WSTETH(), Constants.STETH());

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = Constants.WSTETH();
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
                Constants.WETH(), amount, address(vault), user, address(0)
            );

            ethWrapper.deposit{value: amount}(eth, amount, address(vault), user, address(0));

            assertApproxEqAbs(
                vault.balanceOf(user), IWSTETH(Constants.WSTETH()).getWstETHByStETH(amount), 1 wei
            );

            vm.stopPrank();
        }

        {
            EthWrapper ethWrapper =
                new EthWrapper(Constants.WETH(), Constants.WSTETH(), Constants.STETH());

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = Constants.WSTETH();
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
            EthWrapper ethWrapper =
                new EthWrapper(Constants.WETH(), Constants.WSTETH(), Constants.STETH());

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = Constants.WSTETH();
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
            deal(Constants.WETH(), user, amount);

            IERC20(Constants.WETH()).approve(address(ethWrapper), amount);
            ethWrapper.deposit(Constants.WETH(), amount, address(vault), user, address(0));

            assertApproxEqAbs(
                vault.balanceOf(user), IWSTETH(Constants.WSTETH()).getWstETHByStETH(amount), 1 wei
            );

            vm.stopPrank();
        }

        {
            EthWrapper ethWrapper =
                new EthWrapper(Constants.WETH(), Constants.WSTETH(), Constants.STETH());

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = Constants.WSTETH();
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
            deal(Constants.WETH(), user, amount);

            IERC20(Constants.WETH()).approve(address(ethWrapper), amount);
            vm.expectRevert();
            ethWrapper.deposit(Constants.WETH(), amount, address(vault), user, address(0));

            vm.stopPrank();
        }

        {
            EthWrapper oldWrapper =
                new EthWrapper(Constants.WETH(), Constants.WSTETH(), Constants.STETH());
            EthWrapper ethWrapper =
                new EthWrapper(Constants.WETH(), address(oldWrapper), Constants.STETH());

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = Constants.WSTETH();
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
            deal(Constants.WETH(), user, amount);

            IERC20(Constants.WETH()).approve(address(ethWrapper), amount);
            vm.expectRevert();
            ethWrapper.deposit(Constants.WETH(), amount, address(vault), user, address(0));

            vm.stopPrank();
        }

        {
            EthWrapper ethWrapper =
                new EthWrapper(address(0), Constants.WSTETH(), Constants.WSTETH());

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = Constants.WSTETH();
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
            deal(Constants.WETH(), user, amount);

            IERC20(Constants.WETH()).approve(address(ethWrapper), amount);

            vm.expectRevert();
            ethWrapper.deposit(address(0), amount, address(vault), user, address(0));
            vm.stopPrank();
        }
    }

    function testWstethDeposit() external {
        EthWrapper ethWrapper =
            new EthWrapper(Constants.WETH(), Constants.WSTETH(), Constants.STETH());

        address user = makeAddr("user");

        IdleVault vault = new IdleVault();
        address token = Constants.WSTETH();
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
        deal(Constants.WSTETH(), user, amount);

        IERC20(Constants.WSTETH()).approve(address(ethWrapper), amount);
        ethWrapper.deposit(Constants.WSTETH(), amount, address(vault), user, address(0));

        assertApproxEqAbs(vault.balanceOf(user), amount, 1 wei);

        vm.stopPrank();
    }

    function testStethDeposit() external {
        {
            EthWrapper ethWrapper =
                new EthWrapper(Constants.WETH(), Constants.WSTETH(), Constants.STETH());

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = Constants.WSTETH();
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

            ISTETH(Constants.STETH()).submit{value: amount}(address(0));
            IERC20(Constants.STETH()).approve(address(address(ethWrapper)), amount);

            ethWrapper.deposit(Constants.STETH(), amount, address(vault), user, address(0));

            assertApproxEqAbs(
                vault.balanceOf(user), IWSTETH(Constants.WSTETH()).getWstETHByStETH(amount), 1 wei
            );

            vm.stopPrank();
        }

        {
            EthWrapper ethWrapper =
                new EthWrapper(Constants.WETH(), Constants.WSTETH(), Constants.WSTETH());

            address user = makeAddr("user");

            IdleVault vault = new IdleVault();
            address token = Constants.WSTETH();
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

            ISTETH(Constants.STETH()).submit{value: amount}(address(0));
            IERC20(Constants.STETH()).approve(address(address(ethWrapper)), amount);

            vm.expectRevert();
            ethWrapper.deposit(Constants.STETH(), amount, address(vault), user, address(0));

            vm.stopPrank();
        }
    }

    function testWhitelistedEthWrapper() external {
        address admin = address(1243);
        WhitelistedEthWrapper wrapper = new WhitelistedEthWrapper(
            Constants.WETH(), Constants.WSTETH(), Constants.STETH(), admin
        );

        IdleVault vault = new IdleVault();
        address token = Constants.WSTETH();
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

        vm.startPrank(admin);
        deal(admin, 1 ether);

        wrapper.deposit{value: 1 ether}(
            0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, 1 ether, address(vault), admin, admin
        );

        vm.stopPrank();
    }
}
