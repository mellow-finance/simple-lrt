// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

contract MockERC4626Vault is ERC4626Vault {
    constructor(bytes32 name_, uint256 version_) VaultControlStorage(name_, version_) {}

    function initializeERC4626(
        address _admin,
        uint256 _limit,
        bool _depositPause,
        bool _withdrawalPause,
        bool _depositWhitelist,
        address _asset,
        string memory _name,
        string memory _symbol
    ) external initializer {
        __initializeERC4626(
            _admin,
            _limit,
            _depositPause,
            _withdrawalPause,
            _depositWhitelist,
            _asset,
            _name,
            _symbol
        );
    }

    function test() external pure {}
}

contract Unit is BaseTest {
    address admin = makeAddr("admin");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    uint64 vaultVersion = 1;
    address vaultOwner = makeAddr("vaultOwner");
    address vaultAdmin = makeAddr("vaultAdmin");
    uint48 epochDuration = 3600;
    address wsteth = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;
    address steth = 0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034;
    address weth = 0x94373a4919B3240D86eA41593D5eBa789FEF3848;

    function testInitializeERC4626() external {
        MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
        vault.initializeERC4626(admin, 1000, false, false, false, wsteth, "Wrapped stETH", "wstETH");

        assertEq(vault.name(), "Wrapped stETH");
        assertEq(vault.symbol(), "wstETH");
        assertEq(vault.decimals(), 18);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.limit(), 1000);
        assertEq(vault.depositPause(), false);
        assertEq(vault.withdrawalPause(), false);
        assertEq(vault.depositWhitelist(), false);
        assertEq(vault.asset(), wsteth);

        // DEFAULT_ADMIN_ROLE
        assertTrue(vault.hasRole(bytes32(0), admin));
    }

    function testMaxMint() external {
        {
            MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
            vault.initializeERC4626(
                admin, 1000, false, false, false, wsteth, "Wrapped stETH", "wstETH"
            );

            assertEq(vault.maxMint(address(this)), 1000);
        }

        {
            MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
            vault.initializeERC4626(
                admin, type(uint256).max, false, false, false, wsteth, "Wrapped stETH", "wstETH"
            );

            assertEq(vault.maxMint(address(this)), type(uint256).max);
        }

        {
            MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
            vault.initializeERC4626(
                admin, type(uint256).max, false, false, true, wsteth, "Wrapped stETH", "wstETH"
            );

            assertEq(vault.maxMint(address(this)), 0);
        }

        {
            MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
            vault.initializeERC4626(
                admin, type(uint256).max, false, false, true, wsteth, "Wrapped stETH", "wstETH"
            );

            vm.startPrank(admin);
            vault.grantRole(keccak256("SET_DEPOSITOR_WHITELIST_STATUS_ROLE"), admin);
            vault.setDepositorWhitelistStatus(address(this), true);

            vm.stopPrank();

            assertEq(vault.maxMint(address(this)), type(uint256).max);
        }
    }

    function testMaxDeposit() external {
        {
            MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
            vault.initializeERC4626(
                admin, 1000, false, false, false, wsteth, "Wrapped stETH", "wstETH"
            );

            assertEq(vault.maxDeposit(address(this)), 1000);
        }

        {
            MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
            vault.initializeERC4626(
                admin, type(uint256).max, false, false, false, wsteth, "Wrapped stETH", "wstETH"
            );

            assertEq(vault.maxDeposit(address(this)), type(uint256).max);
        }

        {
            MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
            vault.initializeERC4626(
                admin, type(uint256).max, true, true, true, wsteth, "Wrapped stETH", "wstETH"
            );

            assertEq(vault.maxDeposit(address(this)), 0);
        }

        {
            MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
            vault.initializeERC4626(
                admin, type(uint256).max, false, false, false, wsteth, "Wrapped stETH", "wstETH"
            );

            assertEq(vault.maxDeposit(address(this)), type(uint256).max);
        }

        {
            MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
            vault.initializeERC4626(
                admin, type(uint256).max, false, false, false, wsteth, "Wrapped stETH", "wstETH"
            );

            assertEq(vault.maxDeposit(address(this)), type(uint256).max);
        }

        {
            MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
            vault.initializeERC4626(
                admin, type(uint256).max, false, false, true, wsteth, "Wrapped stETH", "wstETH"
            );

            assertEq(vault.maxDeposit(address(this)), 0);
        }

        {
            MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
            vault.initializeERC4626(
                admin, type(uint256).max, false, false, true, wsteth, "Wrapped stETH", "wstETH"
            );

            vm.startPrank(admin);
            vault.grantRole(keccak256("SET_DEPOSITOR_WHITELIST_STATUS_ROLE"), admin);
            vault.setDepositorWhitelistStatus(address(this), true);

            vm.stopPrank();

            assertEq(vault.maxDeposit(address(this)), type(uint256).max);
        }
    }

    function testDeposit() external {
        vm.startPrank(user1);
        {
            MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
            vault.initializeERC4626(
                admin, 1000, false, false, false, wsteth, "Wrapped stETH", "wstETH"
            );

            uint256 amount = 100;
            deal(wsteth, user1, amount);
            IERC20(wsteth).approve(address(vault), amount);
            vault.deposit(amount, user1);

            assertEq(vault.balanceOf(user1), amount);
            assertEq(vault.totalSupply(), amount);
        }
        {
            MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
            vault.initializeERC4626(
                admin, 1000, true, true, true, wsteth, "Wrapped stETH", "wstETH"
            );

            uint256 amount = 100;
            deal(wsteth, user1, amount);
            IERC20(wsteth).approve(address(vault), amount);
            vm.expectRevert();
            vault.deposit(amount, user1);
        }
        vm.stopPrank();
    }

    function testMint() external {
        vm.startPrank(user1);
        {
            MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
            vault.initializeERC4626(
                admin, 1000, false, false, false, wsteth, "Wrapped stETH", "wstETH"
            );

            uint256 amount = 100;
            deal(wsteth, user1, amount);
            IERC20(wsteth).approve(address(vault), amount);
            vault.mint(amount, user1);

            assertEq(vault.balanceOf(user1), amount);
            assertEq(vault.totalSupply(), amount);
        }

        {
            MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
            vault.initializeERC4626(
                admin, 1000, true, true, true, wsteth, "Wrapped stETH", "wstETH"
            );

            uint256 amount = 100;
            deal(wsteth, user1, amount);
            IERC20(wsteth).approve(address(vault), amount);
            vm.expectRevert();
            vault.mint(amount, user1);
        }

        vm.stopPrank();
    }

    function testMaxWithdraw() external {
        vm.startPrank(user1);
        {
            MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
            vault.initializeERC4626(
                admin, 1000, false, true, false, wsteth, "Wrapped stETH", "wstETH"
            );

            uint256 amount = 100;
            deal(wsteth, user1, amount);
            IERC20(wsteth).approve(address(vault), amount);
            vault.mint(amount, user1);

            assertEq(vault.balanceOf(user1), amount);
            assertEq(vault.totalSupply(), amount);
            assertEq(vault.maxWithdraw(user1), 0);
        }

        {
            MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
            vault.initializeERC4626(
                admin, 1000, false, false, false, wsteth, "Wrapped stETH", "wstETH"
            );

            uint256 amount = 100;
            deal(wsteth, user1, amount);
            IERC20(wsteth).approve(address(vault), amount);
            vault.mint(amount, user1);

            assertEq(vault.balanceOf(user1), amount);
            assertEq(vault.totalSupply(), amount);
            assertEq(vault.maxWithdraw(user1), amount);
        }
        vm.stopPrank();
    }

    function testMaxRedeem() external {
        vm.startPrank(user1);
        {
            MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
            vault.initializeERC4626(
                admin, 1000, false, true, false, wsteth, "Wrapped stETH", "wstETH"
            );

            uint256 amount = 100;
            deal(wsteth, user1, amount);
            IERC20(wsteth).approve(address(vault), amount);
            vault.mint(amount, user1);

            assertEq(vault.balanceOf(user1), amount);
            assertEq(vault.totalSupply(), amount);
            assertEq(vault.maxRedeem(user1), 0);
        }

        {
            MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
            vault.initializeERC4626(
                admin, 1000, false, false, false, wsteth, "Wrapped stETH", "wstETH"
            );

            uint256 amount = 100;
            deal(wsteth, user1, amount);
            IERC20(wsteth).approve(address(vault), amount);
            vault.mint(amount, user1);

            assertEq(vault.balanceOf(user1), amount);
            assertEq(vault.totalSupply(), amount);
            assertEq(vault.maxRedeem(user1), amount);
        }
        vm.stopPrank();
    }

    function testWithdraw() external {
        vm.startPrank(user1);
        {
            MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
            vault.initializeERC4626(
                admin, 1000, false, false, false, wsteth, "Wrapped stETH", "wstETH"
            );

            uint256 amount = 100;
            deal(wsteth, user1, amount);
            IERC20(wsteth).approve(address(vault), amount);
            vault.mint(amount, user1);

            assertEq(vault.balanceOf(user1), amount);
            assertEq(vault.totalSupply(), amount);

            vault.withdraw(amount, user1, user1);

            assertEq(vault.balanceOf(user1), 0);
            assertEq(vault.totalSupply(), 0);
        }

        {
            MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
            vault.initializeERC4626(
                admin, 1000, false, true, false, wsteth, "Wrapped stETH", "wstETH"
            );

            uint256 amount = 100;
            deal(wsteth, user1, amount);
            IERC20(wsteth).approve(address(vault), amount);
            vault.mint(amount, user1);

            assertEq(vault.balanceOf(user1), amount);
            assertEq(vault.totalSupply(), amount);

            vm.expectRevert();
            vault.withdraw(amount, user1, user1);
        }

        vm.stopPrank();
    }

    function testRedeem() external {
        vm.startPrank(user1);
        {
            MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
            vault.initializeERC4626(
                admin, 1000, false, false, false, wsteth, "Wrapped stETH", "wstETH"
            );

            uint256 amount = 100;
            deal(wsteth, user1, amount);
            IERC20(wsteth).approve(address(vault), amount);
            vault.mint(amount, user1);

            assertEq(vault.balanceOf(user1), amount);
            assertEq(vault.totalSupply(), amount);

            vault.redeem(amount, user1, user1);

            assertEq(vault.balanceOf(user1), 0);
            assertEq(vault.totalSupply(), 0);
        }

        {
            MockERC4626Vault vault = new MockERC4626Vault("Vault", vaultVersion);
            vault.initializeERC4626(
                admin, 1000, false, true, false, wsteth, "Wrapped stETH", "wstETH"
            );

            uint256 amount = 100;
            deal(wsteth, user1, amount);
            IERC20(wsteth).approve(address(vault), amount);
            vault.mint(amount, user1);

            assertEq(vault.balanceOf(user1), amount);
            assertEq(vault.totalSupply(), amount);

            vm.expectRevert();
            vault.redeem(amount, user1, user1);
        }

        vm.stopPrank();
    }
}
