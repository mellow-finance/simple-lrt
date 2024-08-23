// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

contract Unit is BaseTest {
    address wsteth = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;
    address steth = 0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034;
    address weth = 0x94373a4919B3240D86eA41593D5eBa789FEF3848;
    address admin = makeAddr("admin");
    address user = makeAddr("user");
    address limitIncreaser = makeAddr("limitIncreaser");

    uint64 vaultVersion = 1;
    address vaultOwner = makeAddr("vaultOwner");
    address vaultAdmin = makeAddr("vaultAdmin");
    uint48 epochDuration = 3600;

    uint256 symbioticLimit = 1000 ether;

    function testFactory() external {
        MellowSymbioticVault singleton = new MellowSymbioticVault("MellowSymbioticVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        ISymbioticVault symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: vaultOwner,
                    vaultAdmin: vaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    isDepositLimit: false,
                    depositLimit: symbioticLimit
                })
            )
        );

        (IMellowSymbioticVault mellowSymbioticVault1, IWithdrawalQueue withdrawalQueue1) = factory
            .create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: makeAddr("proxyAdmin"),
                limit: 100 ether,
                symbioticVault: address(symbioticVault),
                admin: admin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        assertEq(factory.entitiesLength(), 1);
        assertEq(factory.entityAt(0), address(mellowSymbioticVault1));
        assertEq(factory.entities().length, 1);
        assertEq(factory.entities()[0], address(mellowSymbioticVault1));
        assertEq(factory.entityAt(0), address(mellowSymbioticVault1));
        assertEq(factory.isEntity(address(0)), false);
        assertEq(factory.isEntity(address(factory)), false);
        assertEq(factory.isEntity(address(mellowSymbioticVault1)), true);
        assertEq(factory.isEntity(address(withdrawalQueue1)), false);

        (IMellowSymbioticVault mellowSymbioticVault2, IWithdrawalQueue withdrawalQueue2) = factory
            .create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: makeAddr("proxyAdmin"),
                limit: 100 ether,
                symbioticVault: address(symbioticVault),
                admin: admin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        assertEq(factory.entitiesLength(), 2);

        assertEq(factory.entityAt(0), address(mellowSymbioticVault1));
        assertEq(factory.entityAt(1), address(mellowSymbioticVault2));

        assertEq(factory.entities().length, 2);
        assertEq(factory.entities()[0], address(mellowSymbioticVault1));
        assertEq(factory.entities()[1], address(mellowSymbioticVault2));

        assertEq(factory.entityAt(0), address(mellowSymbioticVault1));
        assertEq(factory.entityAt(1), address(mellowSymbioticVault2));

        assertEq(factory.isEntity(address(0)), false);
        assertEq(factory.isEntity(address(factory)), false);
        assertEq(factory.isEntity(address(mellowSymbioticVault1)), true);
        assertEq(factory.isEntity(address(withdrawalQueue1)), false);
        assertEq(factory.isEntity(address(mellowSymbioticVault2)), true);
        assertEq(factory.isEntity(address(withdrawalQueue2)), false);
    }

    function testFactoryZeroAddress() external {
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(0));

        ISymbioticVault symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: vaultOwner,
                    vaultAdmin: vaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    isDepositLimit: false,
                    depositLimit: symbioticLimit
                })
            )
        );

        address proxyAdmin = makeAddr("proxyAdmin");
        // invalid singleton impl
        vm.expectRevert();
        (IMellowSymbioticVault mellowSymbioticVault1, IWithdrawalQueue withdrawalQueue1) = factory
            .create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: proxyAdmin,
                limit: 100 ether,
                symbioticVault: address(symbioticVault),
                admin: admin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );
    }
}
