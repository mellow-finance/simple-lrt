// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

contract Integration is BaseTest {
    using SafeERC20 for IERC20;

    address symbioticVaultConfigurator;
    address migratorAdmin = makeAddr("migratorAdmin");
    uint256 migratorDelay = 1 days;
    address symbioticVaultOwner = makeAddr("symbioticVaultOwner");

    uint48 epochDuration = 604800;

    address mellowLRT = 0x956310119f96fD52590aed4ff213718Ea61d1247;
    address defaultBondStrategy = 0x8b9B55BA5D48D4De08915D14bC561Db30006A307;
    address managedValidator = 0x1Bd18BD7A2DEC5550D5EB1be7717bB23258AED4C;

    address vaultAdmin = 0x2C5f98743e4Cb30d8d65e30B8cd748967D7A051e;
    address proxyAdmin = 0xd67241F8FA670D1eaEd14b7A17B82819087AE86d;
    address proxyAdminOwner = 0x3995c5a3A74f3B3049fD5DA7C7D7BaB0b581A6e1;

    function setUp() external {
        if (block.chainid != 1) {
            revert("This test can only be run on the Ethereum mainnet");
        }
        symbioticVaultConfigurator = symbioticHelper.getSymbioticDeployment().vaultConfigurator;
    }

    function testMigrationOnchain() external {
        MellowVaultCompat mellowVaultCompat =
            new MellowVaultCompat(keccak256("MellowVaultCompat"), 1);
        Migrator migrator =
            new Migrator(address(mellowVaultCompat), address(migratorAdmin), migratorDelay);

        // IVaultConfigurator.InitParams memory emptyParams;
        // emptyParams.vaultParams = .collateral = HOLESKY_WSTETH;
        address symbioticVault = symbioticHelper.createNewSymbioticVault(
            SymbioticHelper.CreationParams({
                vaultOwner: symbioticVaultOwner,
                vaultAdmin: symbioticVaultOwner,
                asset: Constants.WSTETH(),
                epochDuration: epochDuration,
                isDepositLimit: false,
                depositLimit: 0
            })
        );

        vm.startPrank(makeAddr("randomUser"));
        vm.expectRevert();
        migrator.stageMigration(defaultBondStrategy, vaultAdmin, proxyAdmin, symbioticVault);
        vm.stopPrank();

        vm.startPrank(migratorAdmin);
        migrator.stageMigration(defaultBondStrategy, vaultAdmin, proxyAdmin, symbioticVault);

        vm.expectRevert();
        migrator.stageMigration(defaultBondStrategy, vaultAdmin, proxyAdmin, symbioticVault);
        vm.stopPrank();

        skip(migratorDelay);

        vm.startPrank(vaultAdmin);
        bytes32 OPERATOR = keccak256("operator");
        bytes32 ADMIN_DELEGATE_ROLE = keccak256("admin_delegate");
        IAccessControlEnumerable(defaultBondStrategy).grantRole(
            ADMIN_DELEGATE_ROLE, address(vaultAdmin)
        );
        IAccessControlEnumerable(defaultBondStrategy).grantRole(OPERATOR, address(migrator));
        vm.stopPrank();

        vm.startPrank(makeAddr("randomUser"));
        vm.expectRevert();
        migrator.migrate(mellowLRT);
        vm.stopPrank();

        vm.startPrank(migratorAdmin);
        vm.expectRevert();
        migrator.migrate(mellowLRT);
        vm.stopPrank();

        vm.prank(proxyAdminOwner);
        ProxyAdmin(proxyAdmin).transferOwnership(address(migrator));

        vm.prank(migratorAdmin);
        migrator.migrate(mellowLRT);

        MellowVaultCompat(mellowLRT).pushIntoSymbiotic();

        // address deployer = 0x7777775b9E6cE9fbe39568E485f5E20D1b0e04EE;
        // vm.prank(deployer);
        // MellowVaultCompat(mellowLRT).withdraw(10 gwei, deployer, deployer);
    }

    function testMigrationOnchainFails() external {
        MellowVaultCompat mellowVaultCompat =
            new MellowVaultCompat(keccak256("MellowVaultCompat"), 1);
        Migrator migrator =
            new Migrator(address(mellowVaultCompat), address(migratorAdmin), migratorDelay);

        // IVaultConfigurator.InitParams memory emptyParams;
        // emptyParams.vaultParams.collateral = HOLESKY_WSTETH;
        address symbioticVault = symbioticHelper.createNewSymbioticVault(
            SymbioticHelper.CreationParams({
                vaultOwner: symbioticVaultOwner,
                vaultAdmin: symbioticVaultOwner,
                asset: Constants.WSTETH(),
                epochDuration: epochDuration,
                isDepositLimit: false,
                depositLimit: 0
            })
        );

        vm.startPrank(makeAddr("randomUser"));
        vm.expectRevert();
        migrator.stageMigration(defaultBondStrategy, vaultAdmin, proxyAdmin, symbioticVault);
        vm.stopPrank();

        vm.startPrank(migratorAdmin);
        migrator.stageMigration(defaultBondStrategy, vaultAdmin, proxyAdmin, symbioticVault);

        vm.expectRevert();
        migrator.stageMigration(defaultBondStrategy, vaultAdmin, proxyAdmin, symbioticVault);
        vm.stopPrank();

        skip(migratorDelay);

        vm.prank(proxyAdminOwner);
        ProxyAdmin(proxyAdmin).transferOwnership(address(migrator));

        vm.startPrank(migratorAdmin);
        vm.expectRevert();
        migrator.migrate(mellowLRT);

        vm.stopPrank();
    }

    function testMigrationAndWithdraw() external {
        MellowVaultCompat mellowVaultCompat =
            new MellowVaultCompat(keccak256("MellowVaultCompat"), 1);
        Migrator migrator =
            new Migrator(address(mellowVaultCompat), address(migratorAdmin), migratorDelay);

        // IVaultConfigurator.InitParams memory emptyParams;
        // emptyParams.vaultParams.collateral = HOLESKY_WSTETH;
        address symbioticVault = symbioticHelper.createNewSymbioticVault(
            SymbioticHelper.CreationParams({
                vaultOwner: symbioticVaultOwner,
                vaultAdmin: symbioticVaultOwner,
                asset: Constants.WSTETH(),
                epochDuration: epochDuration,
                isDepositLimit: false,
                depositLimit: 0
            })
        );

        vm.prank(migratorAdmin);
        migrator.stageMigration(defaultBondStrategy, vaultAdmin, proxyAdmin, symbioticVault);

        skip(migratorDelay);

        vm.startPrank(vaultAdmin);
        bytes32 OPERATOR = keccak256("operator");
        bytes32 ADMIN_DELEGATE_ROLE = keccak256("admin_delegate");
        IAccessControlEnumerable(defaultBondStrategy).grantRole(
            ADMIN_DELEGATE_ROLE, address(vaultAdmin)
        );
        IAccessControlEnumerable(defaultBondStrategy).grantRole(OPERATOR, address(migrator));
        vm.stopPrank();

        vm.prank(proxyAdminOwner);
        ProxyAdmin(proxyAdmin).transferOwnership(address(migrator));

        vm.prank(migratorAdmin);
        migrator.migrate(mellowLRT);

        // address deployer = 0x7777775b9E6cE9fbe39568E485f5E20D1b0e04EE;
        // vm.prank(deployer);
        // MellowVaultCompat(mellowLRT).withdraw(10 gwei, deployer, deployer);

        // MellowVaultCompat(mellowLRT).pushIntoSymbiotic();

        // vm.prank(deployer);
        // MellowVaultCompat(mellowLRT).withdraw(10 gwei, deployer, deployer);
    }

    function testMigrationZeroDepositLimit() external {
        MellowVaultCompat mellowVaultCompat =
            new MellowVaultCompat(keccak256("MellowVaultCompat"), 1);
        Migrator migrator =
            new Migrator(address(mellowVaultCompat), address(migratorAdmin), migratorDelay);

        // IVaultConfigurator.InitParams memory emptyParams;
        // emptyParams.vaultParams.collateral = HOLESKY_WSTETH;
        address symbioticVault = symbioticHelper.createNewSymbioticVault(
            SymbioticHelper.CreationParams({
                vaultOwner: symbioticVaultOwner,
                vaultAdmin: symbioticVaultOwner,
                asset: Constants.WSTETH(),
                epochDuration: epochDuration,
                isDepositLimit: true,
                depositLimit: 0
            })
        );

        vm.prank(migratorAdmin);
        migrator.stageMigration(defaultBondStrategy, vaultAdmin, proxyAdmin, symbioticVault);

        skip(migratorDelay);

        vm.startPrank(vaultAdmin);
        bytes32 OPERATOR = keccak256("operator");
        bytes32 ADMIN_DELEGATE_ROLE = keccak256("admin_delegate");
        IAccessControlEnumerable(defaultBondStrategy).grantRole(
            ADMIN_DELEGATE_ROLE, address(vaultAdmin)
        );
        IAccessControlEnumerable(defaultBondStrategy).grantRole(OPERATOR, address(migrator));
        vm.stopPrank();

        vm.prank(proxyAdminOwner);
        ProxyAdmin(proxyAdmin).transferOwnership(address(migrator));

        vm.prank(migratorAdmin);
        migrator.migrate(mellowLRT);

        // address deployer = 0x7777775b9E6cE9fbe39568E485f5E20D1b0e04EE;
        // vm.prank(deployer);
        // MellowVaultCompat(mellowLRT).withdraw(10 gwei, deployer, deployer);

        // MellowVaultCompat(mellowLRT).pushIntoSymbiotic();

        // vm.prank(deployer);
        // MellowVaultCompat(mellowLRT).withdraw(10 gwei, deployer, deployer);
    }

    function testMigrationBacklist() external {
        MellowVaultCompat mellowVaultCompat =
            new MellowVaultCompat(keccak256("MellowVaultCompat"), 1);
        Migrator migrator =
            new Migrator(address(mellowVaultCompat), address(migratorAdmin), migratorDelay);

        // IVaultConfigurator.InitParams memory emptyParams;
        // emptyParams.vaultParams.collateral = HOLESKY_WSTETH;
        address symbioticVault = symbioticHelper.createNewSymbioticVault(
            SymbioticHelper.CreationParams({
                vaultOwner: symbioticVaultOwner,
                vaultAdmin: symbioticVaultOwner,
                asset: Constants.WSTETH(),
                epochDuration: epochDuration,
                isDepositLimit: true,
                depositLimit: 0
            })
        );

        vm.prank(symbioticVaultOwner);
        ISymbioticVault(symbioticVault).setDepositWhitelist(true);

        vm.prank(migratorAdmin);
        migrator.stageMigration(defaultBondStrategy, vaultAdmin, proxyAdmin, symbioticVault);

        skip(migratorDelay);

        vm.startPrank(vaultAdmin);
        bytes32 OPERATOR = keccak256("operator");
        bytes32 ADMIN_DELEGATE_ROLE = keccak256("admin_delegate");
        IAccessControlEnumerable(defaultBondStrategy).grantRole(
            ADMIN_DELEGATE_ROLE, address(vaultAdmin)
        );
        IAccessControlEnumerable(defaultBondStrategy).grantRole(OPERATOR, address(migrator));
        vm.stopPrank();

        vm.prank(proxyAdminOwner);
        ProxyAdmin(proxyAdmin).transferOwnership(address(migrator));

        vm.prank(migratorAdmin);
        migrator.migrate(mellowLRT);

        // address deployer = 0x7777775b9E6cE9fbe39568E485f5E20D1b0e04EE;
        // vm.prank(deployer);
        // MellowVaultCompat(mellowLRT).withdraw(10 gwei, deployer, deployer);

        // MellowVaultCompat(mellowLRT).pushIntoSymbiotic();

        // vm.prank(deployer);
        // MellowVaultCompat(mellowLRT).withdraw(10 gwei, deployer, deployer);
    }

    function testMigrationWhitelisted() external {
        MellowVaultCompat mellowVaultCompat =
            new MellowVaultCompat(keccak256("MellowVaultCompat"), 1);
        Migrator migrator =
            new Migrator(address(mellowVaultCompat), address(migratorAdmin), migratorDelay);

        // IVaultConfigurator.InitParams memory emptyParams;
        // emptyParams.vaultParams.collateral = HOLESKY_WSTETH;
        address symbioticVault = symbioticHelper.createNewSymbioticVault(
            SymbioticHelper.CreationParams({
                vaultOwner: symbioticVaultOwner,
                vaultAdmin: symbioticVaultOwner,
                asset: Constants.WSTETH(),
                epochDuration: epochDuration,
                isDepositLimit: true,
                depositLimit: 0
            })
        );

        vm.prank(symbioticVaultOwner);
        ISymbioticVault(symbioticVault).setDepositWhitelist(true);
        vm.prank(symbioticVaultOwner);
        ISymbioticVault(symbioticVault).setDepositorWhitelistStatus(address(mellowLRT), true);

        vm.prank(migratorAdmin);
        migrator.stageMigration(defaultBondStrategy, vaultAdmin, proxyAdmin, symbioticVault);

        skip(migratorDelay);

        vm.startPrank(vaultAdmin);
        bytes32 OPERATOR = keccak256("operator");
        bytes32 ADMIN_DELEGATE_ROLE = keccak256("admin_delegate");
        IAccessControlEnumerable(defaultBondStrategy).grantRole(
            ADMIN_DELEGATE_ROLE, address(vaultAdmin)
        );
        IAccessControlEnumerable(defaultBondStrategy).grantRole(OPERATOR, address(migrator));
        vm.stopPrank();

        vm.prank(proxyAdminOwner);
        ProxyAdmin(proxyAdmin).transferOwnership(address(migrator));

        vm.prank(migratorAdmin);
        migrator.migrate(mellowLRT);

        // address deployer = 0x7777775b9E6cE9fbe39568E485f5E20D1b0e04EE;
        // vm.startPrank(deployer);
        // MellowVaultCompat(mellowLRT).withdraw(10 gwei, deployer, deployer);

        // MellowVaultCompat(mellowLRT).pushIntoSymbiotic();

        // MellowVaultCompat(mellowLRT).withdraw(10 gwei, deployer, deployer);

        // deal(HOLESKY_WSTETH, deployer, 1 ether);
        // IERC20(HOLESKY_WSTETH).approve(address(mellowLRT), 1 ether);
        // MellowVaultCompat(mellowLRT).deposit(1 ether, deployer);

        vm.stopPrank();
    }

    function testFullMigration(
        bool symbioticVaultLimit,
        bool symbioticWhitelist,
        bool isWhitelisted,
        bool collateralLimit,
        bool withPush,
        bool withDeposit
    ) external {
        MellowVaultCompat mellowVaultCompat =
            new MellowVaultCompat(keccak256("MellowVaultCompat"), 1);
        Migrator migrator =
            new Migrator(address(mellowVaultCompat), address(migratorAdmin), migratorDelay);

        // IVaultConfigurator.InitParams memory emptyParams;
        // emptyParams.vaultParams.collateral = HOLESKY_WSTETH;
        address symbioticVault = symbioticHelper.createNewSymbioticVault(
            SymbioticHelper.CreationParams({
                vaultOwner: symbioticVaultOwner,
                vaultAdmin: symbioticVaultOwner,
                asset: Constants.WSTETH(),
                epochDuration: epochDuration,
                isDepositLimit: symbioticVaultLimit,
                depositLimit: 0
            })
        );

        if (!collateralLimit) {
            IDefaultCollateral c = IDefaultCollateral(Constants.WSTETH_SYMBIOTIC_COLLATERAL());
            vm.prank(c.limitIncreaser());
            c.increaseLimit(1e6 ether);
        }

        if (symbioticWhitelist) {
            vm.prank(symbioticVaultOwner);
            ISymbioticVault(symbioticVault).setDepositWhitelist(symbioticWhitelist);
            if (isWhitelisted) {
                vm.prank(symbioticVaultOwner);
                ISymbioticVault(symbioticVault).setDepositorWhitelistStatus(
                    address(mellowLRT), isWhitelisted
                );
            }
        }

        vm.prank(migratorAdmin);
        migrator.stageMigration(defaultBondStrategy, vaultAdmin, proxyAdmin, symbioticVault);

        skip(migratorDelay);

        vm.startPrank(vaultAdmin);
        bytes32 OPERATOR = keccak256("operator");
        bytes32 ADMIN_DELEGATE_ROLE = keccak256("admin_delegate");
        IAccessControlEnumerable(defaultBondStrategy).grantRole(
            ADMIN_DELEGATE_ROLE, address(vaultAdmin)
        );
        IAccessControlEnumerable(defaultBondStrategy).grantRole(OPERATOR, address(migrator));
        vm.stopPrank();

        vm.prank(proxyAdminOwner);
        ProxyAdmin(proxyAdmin).transferOwnership(address(migrator));

        vm.prank(migratorAdmin);
        migrator.migrate(mellowLRT);

        address deployer = 0x7777775b9E6cE9fbe39568E485f5E20D1b0e04EE;
        vm.startPrank(deployer);
        MellowVaultCompat(mellowLRT).withdraw(10 gwei, deployer, deployer);

        if (withPush) {
            MellowVaultCompat(mellowLRT).pushIntoSymbiotic();
        }

        MellowVaultCompat(mellowLRT).withdraw(10 gwei, deployer, deployer);

        if (withDeposit) {
            deal(Constants.WSTETH(), deployer, 1 ether);
            IERC20(Constants.WSTETH()).approve(address(mellowLRT), 1 ether);
            MellowVaultCompat(mellowLRT).deposit(1 ether, deployer);
        }

        vm.stopPrank();
    }

    function testMigrationReassing() external {
        MellowVaultCompat mellowVaultCompat =
            new MellowVaultCompat(keccak256("MellowVaultCompat"), 1);
        Migrator migrator =
            new Migrator(address(mellowVaultCompat), address(migratorAdmin), migratorDelay);

        // IVaultConfigurator.InitParams memory emptyParams;
        // emptyParams.vaultParams.collateral = HOLESKY_WSTETH;
        address symbioticVault = symbioticHelper.createNewSymbioticVault(
            SymbioticHelper.CreationParams({
                vaultOwner: symbioticVaultOwner,
                vaultAdmin: symbioticVaultOwner,
                asset: Constants.WSTETH(),
                epochDuration: epochDuration,
                isDepositLimit: false,
                depositLimit: 0
            })
        );

        vm.prank(migratorAdmin);
        migrator.stageMigration(defaultBondStrategy, vaultAdmin, proxyAdmin, symbioticVault);

        skip(migratorDelay);

        vm.startPrank(vaultAdmin);
        bytes32 OPERATOR = keccak256("operator");
        bytes32 ADMIN_DELEGATE_ROLE = keccak256("admin_delegate");
        IAccessControlEnumerable(defaultBondStrategy).grantRole(
            ADMIN_DELEGATE_ROLE, address(vaultAdmin)
        );
        IAccessControlEnumerable(defaultBondStrategy).grantRole(OPERATOR, address(migrator));
        vm.stopPrank();

        vm.prank(proxyAdminOwner);
        ProxyAdmin(proxyAdmin).transferOwnership(address(migrator));

        vm.startPrank(migratorAdmin);
        migrator.cancelMigration(mellowLRT);

        vm.expectRevert();
        migrator.cancelMigration(mellowLRT);

        vm.stopPrank();
    }

    function testMigrationExt() external {
        MellowVaultCompat mellowVaultCompat =
            new MellowVaultCompat(keccak256("MellowVaultCompat"), 1);
        Migrator migrator =
            new Migrator(address(mellowVaultCompat), address(migratorAdmin), migratorDelay);

        // IVaultConfigurator.InitParams memory emptyParams;
        // emptyParams.vaultParams.collateral = HOLESKY_WSTETH;
        address symbioticVault = symbioticHelper.createNewSymbioticVault(
            SymbioticHelper.CreationParams({
                vaultOwner: symbioticVaultOwner,
                vaultAdmin: symbioticVaultOwner,
                asset: Constants.WSTETH(),
                epochDuration: epochDuration,
                isDepositLimit: false,
                depositLimit: 0
            })
        );

        vm.prank(migratorAdmin);
        migrator.stageMigration(defaultBondStrategy, vaultAdmin, proxyAdmin, symbioticVault);

        skip(migratorDelay);

        vm.startPrank(vaultAdmin);
        bytes32 OPERATOR = keccak256("operator");
        bytes32 ADMIN_DELEGATE_ROLE = keccak256("admin_delegate");
        IAccessControlEnumerable(defaultBondStrategy).grantRole(
            ADMIN_DELEGATE_ROLE, address(vaultAdmin)
        );
        IAccessControlEnumerable(defaultBondStrategy).grantRole(OPERATOR, address(migrator));
        vm.stopPrank();

        vm.prank(proxyAdminOwner);
        ProxyAdmin(proxyAdmin).transferOwnership(address(migrator));

        vm.startPrank(makeAddr("randomUser"));
        vm.expectRevert();
        migrator.cancelMigration(mellowLRT);
        vm.stopPrank();

        // assertNotEq(migrator.migration(mellowLRT).bond, address(0));
        assertNotEq(migrator.vaultInitParams(mellowLRT).symbioticCollateral, address(0));
        assertEq(
            migrator.vaultInitParams(mellowLRT).symbioticCollateral,
            migrator.migration(mellowLRT).bond
        );
    }

    function testConstructorZeroParams() external {
        Migrator migrator = new Migrator(address(0), address(0), 0);
    }

    function testApprovals() external {
        MellowVaultCompat mellowVaultCompat =
            new MellowVaultCompat(keccak256("MellowVaultCompat"), 1);
        Migrator migrator =
            new Migrator(address(mellowVaultCompat), address(migratorAdmin), migratorDelay);

        // IVaultConfigurator.InitParams memory emptyParams;
        // emptyParams.vaultParams.collateral = HOLESKY_WSTETH;
        address symbioticVault = symbioticHelper.createNewSymbioticVault(
            SymbioticHelper.CreationParams({
                vaultOwner: symbioticVaultOwner,
                vaultAdmin: symbioticVaultOwner,
                asset: Constants.WSTETH(),
                epochDuration: epochDuration,
                isDepositLimit: false,
                depositLimit: 0
            })
        );

        address from = makeAddr("from");
        address to = makeAddr("to");
        uint256 amount = 1 ether + 123 wei;
        vm.prank(from);
        IERC20(mellowLRT).forceApprove(to, amount);

        vm.prank(migratorAdmin);
        migrator.stageMigration(defaultBondStrategy, vaultAdmin, proxyAdmin, symbioticVault);

        skip(migratorDelay);

        vm.startPrank(vaultAdmin);
        bytes32 OPERATOR = keccak256("operator");
        bytes32 ADMIN_DELEGATE_ROLE = keccak256("admin_delegate");
        IAccessControlEnumerable(defaultBondStrategy).grantRole(
            ADMIN_DELEGATE_ROLE, address(vaultAdmin)
        );
        IAccessControlEnumerable(defaultBondStrategy).grantRole(OPERATOR, address(migrator));
        vm.stopPrank();

        vm.prank(proxyAdminOwner);
        ProxyAdmin(proxyAdmin).transferOwnership(address(migrator));

        vm.prank(migratorAdmin);
        migrator.migrate(mellowLRT);

        address deployer = 0x7777775b9E6cE9fbe39568E485f5E20D1b0e04EE;
        vm.prank(deployer);
        MellowVaultCompat(mellowLRT).withdraw(10 gwei, deployer, deployer);

        assertEq(MellowVaultCompat(mellowLRT).allowance(from, to), amount);
        MellowVaultCompat(mellowLRT).migrateApproval(from, to);

        assertEq(MellowVaultCompat(mellowLRT).allowance(from, to), amount);
    }
}

interface IManagedValidator {
    function grantRole(address user, uint8 role) external;
}

/*
    Mellow Test ETH
    Vault:  0x956310119f96fD52590aed4ff213718Ea61d1247
    Configurator:  0xe9926e5794595aaA17A18369be8C6204390AAB41
    Validator:  0x1Bd18BD7A2DEC5550D5EB1be7717bB23258AED4C
    DefaultBondStrategy:  0x8b9B55BA5D48D4De08915D14bC561Db30006A307
    DepositWrapper:  0x041cf4dfeBCDad293319F958AC6bad5c62Ee03EE
    HOLESKY_WSTETHAmountDeposited:  9852045351
    TransparentUpgradeableProxy-ProxyAdmin:  0xd67241F8FA670D1eaEd14b7A17B82819087AE86d
    ---------------------------
    Deployer:  0x7777775b9E6cE9fbe39568E485f5E20D1b0e04EE
    ProxyAdmin:  0x3995c5a3A74f3B3049fD5DA7C7D7BaB0b581A6e1
    Admin:  0x2C5f98743e4Cb30d8d65e30B8cd748967D7A051e
    Curator:  0x20daa9d68196aa882A856D0aBBEbB6836Dc4B840
    HOLESKY_WSTETHDefaultBondFactory:  0x7224eeF9f38E9240beA197970367E0A8CBDFDD8B
    HOLESKY_WSTETHDefaultBond:  0x23E98253F372Ee29910e22986fe75Bb287b011fC
    HOLESKY_WSTETH:  0x8d09a4502Cc8Cf1547aD300E066060D043f6982D
    Steth:  0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034
    Weth:  0x94373a4919B3240D86eA41593D5eBa789FEF3848
    MaximalTotalSupply:  10000000000000000000000
    LpTokenName:  Mellow Test ETH
    LpTokenSymbol:  mETH (test)
    InitialDepositETH:  10000000000
    Initializer:  0x2A901514136e0Fa51742c4Ab9C539e35CA904890
    InitialImplementation:  0xcAe4216cbF1038C06c701653070d309f5Ea58ef8
    Erc20TvlModule:  0xF840801D4b5F86aCAe2c43B42AE13573c64c0D71
    DefaultBondTvlModule:  0xdA60626Cc96f2b1dD912E9DE5E9B87A6249deC20
    DefaultBondModule:  0xF392161a9BEf581e80DCC58fa548201B01c02a92
    RatiosOracle:  0xF59f34A1BD7e17b520f3922dD1FB77148abBc10d
    PriceOracle:  0x634c9D1d0ae5475F20008b4E60DdD930BA224709
    WethAggregatorV3:  0x912118DD8978336F6f16B8753c3666042e2828fC
    HOLESKY_WSTETHAggregatorV3:  0xfBc622f4B138A94dB41791CFA13e48A4647834aD
    DefaultProxyImplementation:  0x76106208D69faD40db74BBa8bbb12afAA0699616
*/
