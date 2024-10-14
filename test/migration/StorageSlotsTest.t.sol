// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

import "./Users_0x49cd586dd9BA227Be9654C735A659a1dB08232a9.sol";
import "./Users_0x4f3Cc6359364004b245ad5bE36E6ad4e805dC961.sol";
import "./Users_0x5fD13359Ba15A84B76f7F87568309040176167cd.sol";
import "./Users_0x7a4EffD87C2f3C55CA251080b1343b605f327E3a.sol";
import "./Users_0x7b31F008c48EFb65da78eA0f255EE424af855249.sol";
import "./Users_0x82dc3260f599f4fC4307209A1122B6eAa007163b.sol";
import "./Users_0x84631c0d0081FDe56DeB72F6DE77abBbF6A9f93a.sol";
// import "./Users_0x8c9532a60E0E7C6BbD2B2c1303F63aCE1c3E9811.sol"; // Renzo vault
import "./Users_0xBEEF69Ac7870777598A04B2bd4771c71212E6aBc.sol";
import "./Users_0xd6E09a5e6D719d1c881579C9C8670a210437931b.sol";

contract Integration is BaseTest {
    using SafeERC20 for IERC20;

    struct MigrationData {
        address defaultBondStrategy;
        address vaultAdmin;
        address proxyAdmin;
        address proxyAdminOwner;
        address symbioticVault;
        address offchainData;
    }

    uint256 private constant MIGRATOR_DELAY = 1 days;
    bytes32 private constant SINGLETON_NAME = "MellowVaultCompat";
    uint256 private constant SINGLETON_VERSION = 1;

    address private MIGRATOR_ADMIN = makeAddr("migratorAdmin");
    address private SYMBIOTIC_VAULT_ADMIN = makeAddr("symbioticVaultAdmin");
    address private SYMBIOTIC_VAULT_OWNER = makeAddr("symbioticVaultOwner");

    uint256 private constant SYMBIOTIC_VAULT_EPOCH_DURATION = 7 days;

    Migrator internal migrator;
    MigrationData[] private migrations;

    function setUp() external {
        if (block.chainid != 1) {
            revert("This test can only be run on the Ethereum mainnet");
        }

        migrations.push(
            MigrationData({
                defaultBondStrategy: 0x20ad4d9bbbBBeE7d3abA91558a02c17c3387b834,
                vaultAdmin: 0x9437B2a8cF3b69D782a61f9814baAbc172f72003,
                proxyAdmin: 0xD09b3193bB71B98027dd0f1a34eeAebd04b2e47c,
                proxyAdminOwner: 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0,
                symbioticVault: symbioticHelper.createNewSymbioticVault(
                    SymbioticHelper.CreationParams({
                        vaultOwner: SYMBIOTIC_VAULT_ADMIN,
                        vaultAdmin: SYMBIOTIC_VAULT_OWNER,
                        epochDuration: 7 days,
                        asset: Constants.MAINNET_WSTETH,
                        isDepositLimit: false,
                        depositLimit: 0
                    })
                ),
                offchainData: address(new Users_0x49cd586dd9BA227Be9654C735A659a1dB08232a9())
            })
        );

        migrations.push(
            MigrationData({
                defaultBondStrategy: 0x65fFC47625200A358f5Cdf7103E6D936EcF1a7D5,
                vaultAdmin: 0x9437B2a8cF3b69D782a61f9814baAbc172f72003,
                proxyAdmin: 0x75a7fB388A38E12747D147fD8d38Bbc5Bb860Cf3,
                proxyAdminOwner: 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0,
                symbioticVault: symbioticHelper.createNewSymbioticVault(
                    SymbioticHelper.CreationParams({
                        vaultOwner: SYMBIOTIC_VAULT_ADMIN,
                        vaultAdmin: SYMBIOTIC_VAULT_OWNER,
                        epochDuration: 7 days,
                        asset: Constants.MAINNET_WSTETH,
                        isDepositLimit: false,
                        depositLimit: 0
                    })
                ),
                offchainData: address(new Users_0x4f3Cc6359364004b245ad5bE36E6ad4e805dC961())
            })
        );

        migrations.push(
            MigrationData({
                defaultBondStrategy: 0xc3A149b5Ca3f4A5F17F5d865c14AA9DBb570F10A,
                vaultAdmin: 0x9437B2a8cF3b69D782a61f9814baAbc172f72003,
                proxyAdmin: 0xc24891B75ef55fedC377c5e6Ec59A850b12E23ac,
                proxyAdminOwner: 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0,
                symbioticVault: symbioticHelper.createNewSymbioticVault(
                    SymbioticHelper.CreationParams({
                        vaultOwner: SYMBIOTIC_VAULT_ADMIN,
                        vaultAdmin: SYMBIOTIC_VAULT_OWNER,
                        epochDuration: 7 days,
                        asset: Constants.MAINNET_WSTETH,
                        isDepositLimit: false,
                        depositLimit: 0
                    })
                ),
                offchainData: address(new Users_0x5fD13359Ba15A84B76f7F87568309040176167cd())
            })
        );

        migrations.push(
            MigrationData({
                defaultBondStrategy: 0xA0ea6d4fe369104eD4cc18951B95C3a43573C0F6,
                vaultAdmin: 0x9437B2a8cF3b69D782a61f9814baAbc172f72003,
                proxyAdmin: 0x17AC6A90eD880F9cE54bB63DAb071F2BD3FE3772,
                proxyAdminOwner: 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0,
                symbioticVault: symbioticHelper.createNewSymbioticVault(
                    SymbioticHelper.CreationParams({
                        vaultOwner: SYMBIOTIC_VAULT_ADMIN,
                        vaultAdmin: SYMBIOTIC_VAULT_OWNER,
                        epochDuration: 7 days,
                        asset: Constants.MAINNET_WSTETH,
                        isDepositLimit: false,
                        depositLimit: 0
                    })
                ),
                offchainData: address(new Users_0x7a4EffD87C2f3C55CA251080b1343b605f327E3a())
            })
        );

        migrations.push(
            MigrationData({
                defaultBondStrategy: 0x4Da219961088Cc85B52e13BB1b3c5a64c8d529B7,
                vaultAdmin: 0x9437B2a8cF3b69D782a61f9814baAbc172f72003,
                proxyAdmin: 0x3431224240Fd4e6921ceC32342470b3A55eC175A,
                proxyAdminOwner: 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0,
                symbioticVault: symbioticHelper.createNewSymbioticVault(
                    SymbioticHelper.CreationParams({
                        vaultOwner: SYMBIOTIC_VAULT_ADMIN,
                        vaultAdmin: SYMBIOTIC_VAULT_OWNER,
                        epochDuration: 7 days,
                        asset: Constants.MAINNET_WSTETH,
                        isDepositLimit: false,
                        depositLimit: 0
                    })
                ),
                offchainData: address(new Users_0x7b31F008c48EFb65da78eA0f255EE424af855249())
            })
        );

        migrations.push(
            MigrationData({
                defaultBondStrategy: 0xa80575b793aabD32EDb39759c975534D75a4A2A4,
                vaultAdmin: 0x9437B2a8cF3b69D782a61f9814baAbc172f72003,
                proxyAdmin: 0x3c1C6A3e94Bc607ac947D4520e2E9161a4183D4D,
                proxyAdminOwner: 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0,
                symbioticVault: symbioticHelper.createNewSymbioticVault(
                    SymbioticHelper.CreationParams({
                        vaultOwner: SYMBIOTIC_VAULT_ADMIN,
                        vaultAdmin: SYMBIOTIC_VAULT_OWNER,
                        epochDuration: 7 days,
                        asset: Constants.MAINNET_WSTETH,
                        isDepositLimit: false,
                        depositLimit: 0
                    })
                ),
                offchainData: address(new Users_0x82dc3260f599f4fC4307209A1122B6eAa007163b())
            })
        );

        migrations.push(
            MigrationData({
                defaultBondStrategy: 0xcE3A8820265AD186E8C1CeAED16ae97176D020bA,
                vaultAdmin: 0x9437B2a8cF3b69D782a61f9814baAbc172f72003,
                proxyAdmin: 0xF076CF343DCfD01BBA57dFEB5C74F7B015951fcF,
                proxyAdminOwner: 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0,
                symbioticVault: symbioticHelper.createNewSymbioticVault(
                    SymbioticHelper.CreationParams({
                        vaultOwner: SYMBIOTIC_VAULT_ADMIN,
                        vaultAdmin: SYMBIOTIC_VAULT_OWNER,
                        epochDuration: 7 days,
                        asset: Constants.MAINNET_WSTETH,
                        isDepositLimit: false,
                        depositLimit: 0
                    })
                ),
                offchainData: address(new Users_0x84631c0d0081FDe56DeB72F6DE77abBbF6A9f93a())
            })
        );

        migrations.push(
            MigrationData({
                defaultBondStrategy: 0x7a14b34a9a8EA235C66528dc3bF3aeFC36DFc268,
                vaultAdmin: 0x9437B2a8cF3b69D782a61f9814baAbc172f72003,
                proxyAdmin: 0xed792a3fDEB9044C70c951260AaAe974Fb3dB38F,
                proxyAdminOwner: 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0,
                symbioticVault: symbioticHelper.createNewSymbioticVault(
                    SymbioticHelper.CreationParams({
                        vaultOwner: SYMBIOTIC_VAULT_ADMIN,
                        vaultAdmin: SYMBIOTIC_VAULT_OWNER,
                        epochDuration: 7 days,
                        asset: Constants.MAINNET_WSTETH,
                        isDepositLimit: false,
                        depositLimit: 0
                    })
                ),
                offchainData: address(new Users_0xBEEF69Ac7870777598A04B2bd4771c71212E6aBc())
            })
        );

        migrations.push(
            MigrationData({
                defaultBondStrategy: 0xE73C97e07dF948A046505f8c63c4B54D632D4972,
                vaultAdmin: 0x9437B2a8cF3b69D782a61f9814baAbc172f72003,
                proxyAdmin: 0x0375178C4D752b3ae35D806c6bB60D07faECbA5E,
                proxyAdminOwner: 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0,
                symbioticVault: symbioticHelper.createNewSymbioticVault(
                    SymbioticHelper.CreationParams({
                        vaultOwner: SYMBIOTIC_VAULT_ADMIN,
                        vaultAdmin: SYMBIOTIC_VAULT_OWNER,
                        epochDuration: 7 days,
                        asset: Constants.MAINNET_WSTETH,
                        isDepositLimit: false,
                        depositLimit: 0
                    })
                ),
                offchainData: address(new Users_0xd6E09a5e6D719d1c881579C9C8670a210437931b())
            })
        );

        migrator = new Migrator(
            address(new MellowVaultCompat(SINGLETON_NAME, SINGLETON_VERSION)),
            MIGRATOR_ADMIN,
            MIGRATOR_DELAY
        );
    }

    function stageMigration(uint256 index) public {
        vm.startPrank(MIGRATOR_ADMIN);

        MigrationData memory migration = migrations[index];

        migrator.stageMigration(
            migration.defaultBondStrategy,
            migration.vaultAdmin,
            migration.proxyAdmin,
            migration.symbioticVault
        );

        vm.stopPrank();
    }

    function perpareMigration(uint256 index) public {
        bytes32 ADMIN_ROLE = keccak256("admin");
        bytes32 OPERATOR = keccak256("operator");
        bytes32 ADMIN_DELEGATE_ROLE = keccak256("admin_delegate");

        MigrationData memory migration = migrations[index];
        address strategy = migration.defaultBondStrategy;
        address strategyAdmin = IAccessControlEnumerable(strategy).getRoleMember(ADMIN_ROLE, 0);

        vm.startPrank(strategyAdmin);
        // 1. grant OPERATOR role to the migrator
        if (!IAccessControlEnumerable(strategy).hasRole(ADMIN_DELEGATE_ROLE, strategyAdmin)) {
            IAccessControlEnumerable(strategy).grantRole(ADMIN_DELEGATE_ROLE, strategyAdmin);
        }

        IAccessControlEnumerable(strategy).grantRole(OPERATOR, address(migrator));
        vm.stopPrank();

        // 2. transfer ownership of the ProxyAdmin contract to the migrator
        vm.startPrank(migration.proxyAdminOwner);
        ProxyAdmin(migration.proxyAdmin).transferOwnership(address(migrator));
        vm.stopPrank();
    }

    function commitMigration(uint256 index) public {
        vm.startPrank(MIGRATOR_ADMIN);
        address vault = IDefaultBondStrategy(migrations[index].defaultBondStrategy).vault();
        migrator.migrate(vault);
        vm.stopPrank();
    }

    struct StorageData {
        address[] users;
        uint256[] balances;
        address[] from;
        address[] to;
        uint256[] approvals;
        uint256 totalSupply;
        uint256 totalAssets;
    }

    mapping(uint256 index => StorageData) private storages;

    function loadStoragesBeforeMigration(uint256 index) public {
        address vault = IDefaultBondStrategy(migrations[index].defaultBondStrategy).vault();
        (address[] memory tokens, uint256[] memory amounts) = IMellowLRTExt(vault).baseTvl();
        assertEq(tokens.length, 2);
        assertEq(amounts.length, 2);
        address token0 = Constants.MAINNET_WSTETH;
        address token1 = Constants.MAINNET_WSTETH_SYMBIOTIC_COLLATERAL;
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }
        assertEq(tokens[0], token0);
        assertEq(tokens[1], token1);
        storages[index].totalSupply = IERC20(vault).totalSupply();
        storages[index].totalAssets = amounts[0] + amounts[1];

        IOffchainData offchainData = IOffchainData(migrations[index].offchainData);
        for (uint256 i = 0;; i++) {
            try offchainData.users(i) returns (address user_) {
                storages[index].users.push(user_);
            } catch {
                break;
            }
        }

        for (uint256 i = 0;; i++) {
            try offchainData.approvalsFrom(i) returns (address from_) {
                storages[index].from.push(from_);
                storages[index].to.push(offchainData.approvalsTo(i));
            } catch {
                break;
            }
        }

        uint256 cumulativeSupply = 0;
        for (uint256 i = 0; i < storages[index].users.length; i++) {
            uint256 balance = IERC20(vault).balanceOf(storages[index].users[i]);
            storages[index].balances.push(balance);
            cumulativeSupply += balance;
        }

        assertEq(cumulativeSupply, storages[index].totalSupply);

        for (uint256 i = 0; i < storages[index].from.length; i++) {
            storages[index].approvals.push(
                IERC20(vault).allowance(storages[index].from[i], storages[index].to[i])
            );
        }
    }

    function validateStoragesAfterMigration(uint256 index) public {
        address vault = IDefaultBondStrategy(migrations[index].defaultBondStrategy).vault();
        assertEq(storages[index].totalSupply, MellowVaultCompat(vault).totalSupply());
        assertEq(storages[index].totalAssets, MellowVaultCompat(vault).totalAssets());

        for (uint256 i = 0; i < storages[index].users.length; i++) {
            assertEq(
                storages[index].balances[i],
                MellowVaultCompat(vault).balanceOf(storages[index].users[i])
            );
        }

        assertEq(
            MellowVaultCompat(vault).compatTotalSupply(), MellowVaultCompat(vault).totalSupply()
        );
        MellowVaultCompat(vault).migrateMultiple(storages[index].users);

        assertEq(MellowVaultCompat(vault).compatTotalSupply(), 0);

        for (uint256 i = 0; i < storages[index].users.length; i++) {
            assertEq(
                storages[index].balances[i],
                MellowVaultCompat(vault).balanceOf(storages[index].users[i])
            );
        }

        for (uint256 i = 0; i < storages[index].from.length; i++) {
            assertEq(
                storages[index].approvals[i],
                MellowVaultCompat(vault).allowance(storages[index].from[i], storages[index].to[i])
            );
        }

        for (uint256 i = 0; i < storages[index].from.length; i++) {
            MellowVaultCompat(vault).migrateApproval(storages[index].from[i], storages[index].to[i]);
        }

        for (uint256 i = 0; i < storages[index].from.length; i++) {
            assertEq(
                storages[index].approvals[i],
                MellowVaultCompat(vault).allowance(storages[index].from[i], storages[index].to[i])
            );
        }
    }

    function beforeMigration(uint256 index) internal {
        bytes32 ADMIN_ROLE = keccak256("admin");
        MigrationData memory migration = migrations[index];
        address strategy = migration.defaultBondStrategy;
        address strategyAdmin = IAccessControlEnumerable(strategy).getRoleMember(ADMIN_ROLE, 0);
        vm.startPrank(strategyAdmin);
        IDefaultBondStrategy(strategy).processAll();
        vm.stopPrank();
    }

    function testMigrations() external {
        uint256 n = migrations.length;

        for (uint256 i = 0; i < n; i++) {
            beforeMigration(i);
            loadStoragesBeforeMigration(i);
            stageMigration(i);
        }

        skip(7 days);

        for (uint256 i = 0; i < n; i++) {
            perpareMigration(i);
        }

        for (uint256 i = 0; i < n; i++) {
            commitMigration(i);
            validateStoragesAfterMigration(i);
        }
    }
}

interface IMellowLRTExt {
    function baseTvl() external view returns (address[] memory tokens, uint256[] memory amounts);
}

interface IOffchainData {
    function users(uint256 index) external view returns (address);
    function approvalsFrom(uint256 index) external view returns (address);
    function approvalsTo(uint256 index) external view returns (address);
}

// 2.5 hours to run the test...
