// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

contract Integration is BaseTest {
    address symbioticVaultConfigurator;
    uint256 migratorDelay = 1 days;
    address symbioticVaultOwner = makeAddr("symbioticVaultOwner");
    address wsteth = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;
    address steth = 0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034;
    address weth = 0x94373a4919B3240D86eA41593D5eBa789FEF3848;

    uint48 epochDuration = 604800;

    address mellowLRT = 0x956310119f96fD52590aed4ff213718Ea61d1247;
    address defaultBondStrategy = 0x8b9B55BA5D48D4De08915D14bC561Db30006A307;
    address managedValidator = 0x1Bd18BD7A2DEC5550D5EB1be7717bB23258AED4C;

    address vaultAdmin = 0x2C5f98743e4Cb30d8d65e30B8cd748967D7A051e;
    address proxyAdmin = 0xd67241F8FA670D1eaEd14b7A17B82819087AE86d;
    address proxyAdminOwner = 0x3995c5a3A74f3B3049fD5DA7C7D7BaB0b581A6e1;

    address migratorAdmin = proxyAdminOwner;

    function testTwoStepMigrationOnchain() external {
        symbioticVaultConfigurator = symbioticHelper.symbioticContracts().VAULT_CONFIGURATOR();

        MellowVaultCompat mellowVaultCompat =
            new MellowVaultCompat(keccak256("MellowVaultCompat"), 1);
        TwoStepMigrator migrator = new TwoStepMigrator(
            address(mellowVaultCompat),
            address(symbioticVaultConfigurator),
            address(migratorAdmin),
            migratorDelay
        );

        IVaultConfigurator.InitParams memory emptyParams;
        emptyParams.vaultParams.collateral = wsteth;
        address symbioticVault = symbioticHelper.createNewSymbioticVault(
            SymbioticHelper.CreationParams({
                vaultOwner: symbioticVaultOwner,
                vaultAdmin: symbioticVaultOwner,
                asset: wsteth,
                epochDuration: epochDuration,
                isDepositLimit: false,
                depositLimit: 0
            })
        );

        vm.prank(migratorAdmin);
        uint256 migrationIndex = migrator.stageMigration(
            defaultBondStrategy, vaultAdmin, proxyAdmin, proxyAdminOwner, symbioticVault
        );

        skip(migratorDelay);

        vm.startPrank(vaultAdmin);
        bytes32 ADMIN_ROLE = keccak256("admin");
        IAccessControlEnumerable(mellowLRT).grantRole(ADMIN_ROLE, address(migrator));
        IAccessControlEnumerable(defaultBondStrategy).grantRole(ADMIN_ROLE, address(migrator));
        IManagedValidator(managedValidator).grantRole(address(migrator), 255);

        vm.stopPrank();

        vm.startPrank(migratorAdmin);
        migrator.migrate(migrationIndex);
        ProxyAdmin(proxyAdmin).upgradeAndCall(
            ITransparentUpgradeableProxy(mellowLRT), address(mellowVaultCompat), new bytes(0)
        );
        migrator.initializeVault(migrationIndex);
        vm.stopPrank();

        MellowVaultCompat(mellowLRT).pushIntoSymbiotic();
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
    WstethAmountDeposited:  9852045351
    TransparentUpgradeableProxy-ProxyAdmin:  0xd67241F8FA670D1eaEd14b7A17B82819087AE86d
    ---------------------------
    Deployer:  0x7777775b9E6cE9fbe39568E485f5E20D1b0e04EE
    ProxyAdmin:  0x3995c5a3A74f3B3049fD5DA7C7D7BaB0b581A6e1
    Admin:  0x2C5f98743e4Cb30d8d65e30B8cd748967D7A051e
    Curator:  0x20daa9d68196aa882A856D0aBBEbB6836Dc4B840
    WstethDefaultBondFactory:  0x7224eeF9f38E9240beA197970367E0A8CBDFDD8B
    WstethDefaultBond:  0x23E98253F372Ee29910e22986fe75Bb287b011fC
    Wsteth:  0x8d09a4502Cc8Cf1547aD300E066060D043f6982D
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
    WstethAggregatorV3:  0xfBc622f4B138A94dB41791CFA13e48A4647834aD
    DefaultProxyImplementation:  0x76106208D69faD40db74BBa8bbb12afAA0699616
*/
