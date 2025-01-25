// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../scripts/mainnet/MigrationDeploy.sol";
import "../BaseTest.sol";

import "../Constants.sol";
import "./AcceptanceMigrationRunner.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract AcceptanceMigrationTest is Test {
    /// docs: https://www.notion.so/mellowprotocol/roETH-migration-process-adaa9b9d9d0045d682fd4b91ab3d2423

    Migrator migrator = Migrator(0x643ED3c06E19A96EaBCBC32C2F665DB16282bEaB);
    address vaultAdminMultisig = 0x9437B2a8cF3b69D782a61f9814baAbc172f72003;
    address vaultProxyAdminMultisig = 0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0;
    address wsteth = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address defaultCollateralWstETH = 0xC329400492c6ff2438472D4651Ad17389fCb843a;

    address IMPLEMENTATION_BEFORE = 0xaf108ae0AD8700ac41346aCb620e828c03BB8848;
    address IMPLEMENTATION_AFTER = 0x09bBa67C316e59840699124a8DC0bBDa6A2A9d59;

    bytes32 ADMIN_DELEGATE_ROLE = keccak256("admin_delegate");
    bytes32 OPERATOR = keccak256("operator");

    string ROETH_NAME = "Rockmelon ETH";
    string ROETH_SYMBOL = "roETH";

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZABLE_STORAGE =
        0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    function testAcceptanceRoETHMigration() external {
        assertEq(migrator.singleton(), IMPLEMENTATION_AFTER, "Invalid singleton implementation");
        address symbioticVault = 0x575d6DD4EA8636E08952Bd7f8AF977081754B1B7;

        address strategy = 0x4Da219961088Cc85B52e13BB1b3c5a64c8d529B7;
        address vault = 0x7b31F008c48EFb65da78eA0f255EE424af855249;
        address proxyAdmin = 0x3431224240Fd4e6921ceC32342470b3A55eC175A;

        // created upon 'stageMigration' call of the Migrator contract
        address EXPECTED_WITHDRAWAL_QUEUE = 0xe51241aAbE7c77F658A3Bf160D922a1E936168cd;

        IMellowLRT.ProcessWithdrawalsStack memory stack;

        // stage phase:
        {
            // stage.1 - symbioticVault = 0x575d6DD4EA8636E08952Bd7f8AF977081754B1B7

            if (block.number < 21696723) {
                {
                    assertEq(migrator.timestamps(vault), 0, "Migration already started");
                    IMigrator.Parameters memory emptyParams;
                    assertEq(
                        keccak256(abi.encode(migrator.migration(vault))),
                        keccak256(abi.encode(emptyParams)),
                        "Migration already started"
                    );
                    IMellowSymbioticVault.InitParams memory emptyInitParams;
                    assertEq(
                        keccak256(abi.encode(migrator.vaultInitParams(vault))),
                        keccak256(abi.encode(emptyInitParams)),
                        "Migration already started"
                    );
                }

                // stage.2:
                vm.startPrank(vaultProxyAdminMultisig);
                migrator.stageMigration(strategy, vaultAdminMultisig, proxyAdmin, symbioticVault);
                vm.stopPrank();
                assertEq(migrator.timestamps(vault), block.timestamp, "Invalid timestamp");
            } else {
                assertEq(migrator.timestamps(vault), 1737750167, "Invalid timestamp");
            }

            {
                IMigrator.Parameters memory expectedParams = IMigrator.Parameters({
                    proxyAdmin: proxyAdmin,
                    proxyAdminOwner: vaultProxyAdminMultisig,
                    token: wsteth,
                    bond: defaultCollateralWstETH,
                    defaultBondStrategy: strategy
                });
                assertEq(
                    keccak256(abi.encode(migrator.migration(vault))),
                    keccak256(abi.encode(expectedParams)),
                    "invalid migration params"
                );

                IMellowSymbioticVault.InitParams memory expectedVaultInitParams =
                IMellowSymbioticVault.InitParams({
                    limit: 0,
                    symbioticCollateral: defaultCollateralWstETH,
                    symbioticVault: symbioticVault,
                    withdrawalQueue: EXPECTED_WITHDRAWAL_QUEUE,
                    admin: vaultAdminMultisig,
                    depositPause: true,
                    withdrawalPause: true,
                    depositWhitelist: false,
                    name: ROETH_NAME,
                    symbol: ROETH_SYMBOL
                });
                assertEq(
                    keccak256(abi.encode(migrator.vaultInitParams(vault))),
                    keccak256(abi.encode(expectedVaultInitParams)),
                    "invalid vault init params"
                );
            }

            {
                assertFalse(
                    IAccessControl(strategy).hasRole(ADMIN_DELEGATE_ROLE, vaultAdminMultisig),
                    "Admin delegate role already granted"
                );
                assertFalse(
                    IAccessControl(strategy).hasRole(OPERATOR, address(migrator)),
                    "Operator role already granted"
                );
            }

            // stage.3:
            vm.startPrank(vaultAdminMultisig);
            IAccessControl(strategy).grantRole(ADMIN_DELEGATE_ROLE, vaultAdminMultisig);
            IAccessControl(strategy).grantRole(OPERATOR, address(migrator));
            vm.stopPrank();

            {
                assertTrue(
                    IAccessControl(strategy).hasRole(ADMIN_DELEGATE_ROLE, vaultAdminMultisig),
                    "Admin delegate role not granted"
                );
                assertTrue(
                    IAccessControl(strategy).hasRole(OPERATOR, address(migrator)),
                    "Operator role not granted"
                );
            }
        }

        skip(migrator.migrationDelay());

        // commit phase:
        {
            // commit.1:
            vm.startPrank(vaultAdminMultisig);
            IDefaultBondStrategy(strategy).processAll();
            vm.stopPrank();

            stack = IMellowLRT(vault).calculateStack();

            {
                assertEq(
                    IMellowLRT(vault).pendingWithdrawersCount(),
                    0,
                    "Pending withdrawals not processed"
                );
            }

            {
                assertEq(
                    ProxyAdmin(proxyAdmin).owner(),
                    vaultProxyAdminMultisig,
                    "Invalid proxy admin owner"
                );
            }

            // commit.2:
            {
                vm.startPrank(vaultProxyAdminMultisig);
                ProxyAdmin(proxyAdmin).transferOwnership(address(migrator));
                vm.stopPrank();
            }

            {
                assertEq(
                    ProxyAdmin(proxyAdmin).owner(), address(migrator), "Invalid proxy admin owner"
                );
            }

            {
                assertEq(migrator.entitiesLength(), 0, "Invalid entities length");
                assertFalse(migrator.isEntity(vault), "Entity already exists");

                address implementationBefore =
                    address(uint160(uint256(vm.load(vault, ERC1967Utils.IMPLEMENTATION_SLOT))));

                assertEq(
                    implementationBefore, IMPLEMENTATION_BEFORE, "Invalid implementation before"
                );

                bytes32 initialization = vm.load(vault, INITIALIZABLE_STORAGE);
                assertEq(
                    initialization, bytes32(0), "Invalid initialization storage before migration"
                );
            }

            // commit.3:
            {
                vm.startPrank(vaultProxyAdminMultisig);
                migrator.migrate(vault);
                vm.stopPrank();
            }

            {
                assertEq(migrator.entitiesLength(), 1, "Invalid entities length");
                assertTrue(migrator.isEntity(vault), "Entity not exists");

                address implementationAfter =
                    address(uint160(uint256(vm.load(vault, ERC1967Utils.IMPLEMENTATION_SLOT))));

                assertEq(implementationAfter, IMPLEMENTATION_AFTER, "Invalid implementation after");
                bytes32 initialization = vm.load(vault, INITIALIZABLE_STORAGE);
                assertEq(
                    initialization,
                    bytes32(uint256(1)),
                    "Invalid initialization storage after migration"
                );

                MellowVaultCompat c = MellowVaultCompat(vault);
                assertEq(c.asset(), wsteth, "Invalid asset after migration");
                assertEq(
                    address(c.symbioticVault()),
                    symbioticVault,
                    "Invalid symbiotic vault after migration"
                );
                assertEq(
                    address(c.withdrawalQueue()),
                    EXPECTED_WITHDRAWAL_QUEUE,
                    "Invalid withdrawal queue after migration"
                );
                assertTrue(
                    c.hasRole(c.DEFAULT_ADMIN_ROLE(), vaultAdminMultisig),
                    "Invalid admin after migration"
                );
                assertEq(
                    c.getRoleMemberCount(c.DEFAULT_ADMIN_ROLE()),
                    1,
                    "Invalid admin count after migration"
                );

                bytes32[8] memory roles = [
                    keccak256("SET_FARM_ROLE"),
                    keccak256("SET_LIMIT_ROLE"),
                    keccak256("PAUSE_WITHDRAWALS_ROLE"),
                    keccak256("UNPAUSE_WITHDRAWALS_ROLE"),
                    keccak256("PAUSE_DEPOSITS_ROLE"),
                    keccak256("UNPAUSE_DEPOSITS_ROLE"),
                    keccak256("SET_DEPOSIT_WHITELIST_ROLE"),
                    keccak256("SET_DEPOSITOR_WHITELIST_STATUS_ROLE")
                ];
                for (uint256 i = 0; i < roles.length; i++) {
                    assertEq(
                        c.getRoleMemberCount(roles[i]),
                        0,
                        "Invalid role member count after migration"
                    );
                }

                assertEq(c.depositPause(), true, "Invalid deposit pause after migration");
                assertEq(c.withdrawalPause(), true, "Invalid withdrawal pause after migration");
                assertEq(c.depositWhitelist(), false, "Invalid deposit whitelist after migration");
                assertEq(
                    keccak256(abi.encode(c.name())),
                    keccak256(abi.encode(ROETH_NAME)),
                    "Invalid name after migration"
                );
                assertEq(
                    keccak256(abi.encode(c.symbol())),
                    keccak256(abi.encode(ROETH_SYMBOL)),
                    "Invalid symbol after migration"
                );
                assertEq(
                    address(c.symbioticCollateral()),
                    address(defaultCollateralWstETH),
                    "Invalid symbiotic collateral after migration"
                );

                assertEq(
                    c.compatTotalSupply(), c.totalSupply(), "Invalid total supply after migration"
                );
                // NOTE: ETH->WSTETH CONVERSION!!!
                assertApproxEqAbs(
                    IWSTETH(wsteth).getWstETHByStETH(stack.totalValue),
                    c.totalAssets(),
                    1 wei,
                    "Invalid total assets after migration"
                );
                assertEq(stack.totalSupply, c.totalSupply(), "Invalid total supply after migration");
            }
        }
    }
}
