// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockVault is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function test() external pure {}
}

contract Unit is BaseTest {
    address proxyAdmin = makeAddr("proxyAdmin");
    address admin = makeAddr("proxyAdmin");

    function testMellowVaultCompat() external {
        MockVault initialSingleton = new MockVault("MockVault", "MV");
        MellowVaultCompat newSigleton = new MellowVaultCompat(keccak256("MockVault-new"), 1);

        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(initialSingleton), proxyAdmin, "");

        uint256 n = 10;

        address[] memory users = new address[](n);
        uint256[] memory balances = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            users[i] = address(bytes20(keccak256(abi.encodePacked(i * 12341241))));
            balances[i] = 1 ether + i;
            MockVault(address(proxy)).mint(users[i], balances[i]);
        }

        uint256 totalSupplyBefore = MockVault(address(proxy)).totalSupply();

        ProxyAdmin prAdmin =
            ProxyAdmin(address(uint160(uint256(vm.load(address(proxy), ERC1967Utils.ADMIN_SLOT)))));

        vm.startPrank(proxyAdmin);
        prAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(proxy)), address(newSigleton), new bytes(0)
        );
        vm.stopPrank();

        for (uint256 i = 0; i < n; i++) {
            assertEq(MellowVaultCompat(address(proxy)).balanceOf(users[i]), balances[i]);
        }

        assertEq(MellowVaultCompat(address(proxy)).totalSupply(), totalSupplyBefore);
        assertEq(MellowVaultCompat(address(proxy)).compatTotalSupply(), totalSupplyBefore);

        MellowVaultCompat(address(proxy)).migrateMultiple(users);

        for (uint256 i = 0; i < n; i++) {
            assertEq(MellowVaultCompat(address(proxy)).balanceOf(users[i]), balances[i]);
        }

        assertEq(MellowVaultCompat(address(proxy)).totalSupply(), totalSupplyBefore);
        assertEq(MellowVaultCompat(address(proxy)).compatTotalSupply(), 0);

        MellowSymbioticVault newSigleton2 = new MellowSymbioticVault(keccak256("MockVault-new"), 1);

        vm.startPrank(proxyAdmin);
        prAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(proxy)), address(newSigleton2), new bytes(0)
        );
        vm.stopPrank();

        for (uint256 i = 0; i < n; i++) {
            assertEq(MellowSymbioticVault(address(proxy)).balanceOf(users[i]), balances[i]);
        }

        assertEq(MellowSymbioticVault(address(proxy)).totalSupply(), totalSupplyBefore);
    }

    function testMellowVaultCompatSingleMigrate() external {
        MockVault initialSingleton = new MockVault("MockVault", "MV");
        MellowVaultCompat newSigleton = new MellowVaultCompat(keccak256("MockVault-new"), 1);

        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(initialSingleton), proxyAdmin, "");

        uint256 n = 10;

        address[] memory users = new address[](n);
        uint256[] memory balances = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            users[i] = address(bytes20(keccak256(abi.encodePacked(i * 12341241))));
            balances[i] = 1 ether + i;
            MockVault(address(proxy)).mint(users[i], balances[i]);
        }

        uint256 totalSupplyBefore = MockVault(address(proxy)).totalSupply();

        ProxyAdmin prAdmin =
            ProxyAdmin(address(uint160(uint256(vm.load(address(proxy), ERC1967Utils.ADMIN_SLOT)))));

        vm.startPrank(proxyAdmin);
        prAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(proxy)), address(newSigleton), new bytes(0)
        );
        vm.stopPrank();

        for (uint256 i = 0; i < n; i++) {
            assertEq(MellowVaultCompat(address(proxy)).balanceOf(users[i]), balances[i]);
        }

        assertEq(MellowVaultCompat(address(proxy)).totalSupply(), totalSupplyBefore);
        assertEq(MellowVaultCompat(address(proxy)).compatTotalSupply(), totalSupplyBefore);

        for (uint256 i = 0; i < n; i++) {
            MellowVaultCompat(address(proxy)).migrate(users[i]);
        }

        for (uint256 i = 0; i < n; i++) {
            assertEq(MellowVaultCompat(address(proxy)).balanceOf(users[i]), balances[i]);
        }

        assertEq(MellowVaultCompat(address(proxy)).totalSupply(), totalSupplyBefore);
        assertEq(MellowVaultCompat(address(proxy)).compatTotalSupply(), 0);

        MellowSymbioticVault newSigleton2 = new MellowSymbioticVault(keccak256("MockVault-new"), 1);

        vm.startPrank(proxyAdmin);
        prAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(proxy)), address(newSigleton2), new bytes(0)
        );
        vm.stopPrank();

        for (uint256 i = 0; i < n; i++) {
            assertEq(MellowSymbioticVault(address(proxy)).balanceOf(users[i]), balances[i]);
        }

        assertEq(MellowSymbioticVault(address(proxy)).totalSupply(), totalSupplyBefore);
    }

    function testMellowVaultCompatTransfer() external {
        MockVault initialSingleton = new MockVault("MockVault", "MV");
        MellowVaultCompat newSigleton = new MellowVaultCompat(keccak256("MockVault-new"), 1);

        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(initialSingleton), proxyAdmin, "");

        uint256 n = 10;

        address[] memory users = new address[](n);
        uint256[] memory balances = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            users[i] = address(bytes20(keccak256(abi.encodePacked(i * 12341241))));
            balances[i] = 1 ether + i;
            MockVault(address(proxy)).mint(users[i], balances[i]);
        }

        uint256 totalSupplyBefore = MockVault(address(proxy)).totalSupply();

        ProxyAdmin prAdmin =
            ProxyAdmin(address(uint160(uint256(vm.load(address(proxy), ERC1967Utils.ADMIN_SLOT)))));

        vm.startPrank(proxyAdmin);
        prAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(proxy)), address(newSigleton), new bytes(0)
        );
        vm.stopPrank();

        for (uint256 i = 0; i < n; i++) {
            assertEq(MellowVaultCompat(address(proxy)).balanceOf(users[i]), balances[i]);
        }

        assertEq(MellowVaultCompat(address(proxy)).totalSupply(), totalSupplyBefore);
        assertEq(MellowVaultCompat(address(proxy)).compatTotalSupply(), totalSupplyBefore);

        for (uint256 i = 0; i < n; i++) {
            vm.prank(users[i]);
            MellowVaultCompat(address(proxy)).transfer(users[i], 0);
        }

        for (uint256 i = 0; i < n; i++) {
            assertEq(MellowVaultCompat(address(proxy)).balanceOf(users[i]), balances[i]);
        }

        assertEq(MellowVaultCompat(address(proxy)).totalSupply(), totalSupplyBefore);
        assertEq(MellowVaultCompat(address(proxy)).compatTotalSupply(), 0);

        MellowSymbioticVault newSigleton2 = new MellowSymbioticVault(keccak256("MockVault-new"), 1);

        vm.startPrank(proxyAdmin);
        prAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(proxy)), address(newSigleton2), new bytes(0)
        );
        vm.stopPrank();

        for (uint256 i = 0; i < n; i++) {
            assertEq(MellowSymbioticVault(address(proxy)).balanceOf(users[i]), balances[i]);
        }

        assertEq(MellowSymbioticVault(address(proxy)).totalSupply(), totalSupplyBefore);
    }
}
