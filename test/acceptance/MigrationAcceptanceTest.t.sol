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

    bytes32 ADMIN_DELEGATE_ROLE = keccak256("admin_delegate");
    bytes32 OPERATOR = keccak256("operator");

    function testAcceptanceRoETHMigration() external {
        address symbioticVault = 0x575d6DD4EA8636E08952Bd7f8AF977081754B1B7;

        address strategy = 0x4Da219961088Cc85B52e13BB1b3c5a64c8d529B7;
        address vault = 0x7b31F008c48EFb65da78eA0f255EE424af855249;
        address proxyAdmin = 0x3431224240Fd4e6921ceC32342470b3A55eC175A;

        // created upon 'stageMigration' call of the Migrator contract
        address EXPECTED_WITHDRAWAL_QUEUE = 0xe51241aAbE7c77F658A3Bf160D922a1E936168cd;

        // stage phase:
        {
            // stage.1 - symbioticVault = 0x575d6DD4EA8636E08952Bd7f8AF977081754B1B7

            {
                require(migrator.timestamps(vault) == 0, "Migration already started");
                IMigrator.Parameters memory emptyParams;
                require(
                    keccak256(abi.encode(migrator.migration(vault)))
                        == keccak256(abi.encode(emptyParams)),
                    "Migration already started"
                );
                IMellowSymbioticVault.InitParams memory emptyInitParams;
                require(
                    keccak256(abi.encode(migrator.vaultInitParams(vault)))
                        == keccak256(abi.encode(emptyInitParams)),
                    "Migration already started"
                );
            }

            // stage.2:
            vm.startPrank(vaultProxyAdminMultisig);
            migrator.stageMigration(strategy, vaultAdminMultisig, proxyAdmin, symbioticVault);
            vm.stopPrank();

            {
                require(migrator.timestamps(vault) == block.timestamp, "Invalid timestamp");
                IMigrator.Parameters memory expectedParams = IMigrator.Parameters({
                    proxyAdmin: proxyAdmin,
                    proxyAdminOwner: vaultProxyAdminMultisig,
                    token: wsteth,
                    bond: defaultCollateralWstETH,
                    defaultBondStrategy: strategy
                });
                require(
                    keccak256(abi.encode(migrator.migration(vault)))
                        == keccak256(abi.encode(expectedParams)),
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
                    name: ERC20(vault).name(),
                    symbol: ERC20(vault).symbol()
                });
                require(
                    keccak256(abi.encode(migrator.vaultInitParams(vault)))
                        == keccak256(abi.encode(expectedVaultInitParams)),
                    "invalid vault init params"
                );
            }

            {
                require(
                    !IAccessControl(strategy).hasRole(ADMIN_DELEGATE_ROLE, vaultAdminMultisig),
                    "Admin delegate role already granted"
                );
                require(
                    !IAccessControl(strategy).hasRole(OPERATOR, address(migrator)),
                    "Operator role already granted"
                );
            }

            // stage.3:
            vm.startPrank(vaultAdminMultisig);
            IAccessControl(strategy).grantRole(ADMIN_DELEGATE_ROLE, vaultAdminMultisig);
            IAccessControl(strategy).grantRole(OPERATOR, address(migrator));
            vm.stopPrank();

            {
                require(
                    IAccessControl(strategy).hasRole(ADMIN_DELEGATE_ROLE, vaultAdminMultisig),
                    "Admin delegate role not granted"
                );
                require(
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

            {
                require(
                    IMellowLRT(vault).pendingWithdrawersCount() == 0,
                    "Pending withdrawals not processed"
                );
            }

            {
                require(
                    ProxyAdmin(proxyAdmin).owner() == vaultProxyAdminMultisig,
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
                require(
                    ProxyAdmin(proxyAdmin).owner() == address(migrator), "Invalid proxy admin owner"
                );
            }

            {
                require(migrator.entitiesLength() == 0, "Invalid entities length");
                require(!migrator.isEntity(vault), "Entity already exists");
            }

            // commit.3:
            {
                vm.startPrank(vaultProxyAdminMultisig);
                migrator.migrate(vault);
                vm.stopPrank();
            }

            {
                require(migrator.entitiesLength() == 1, "Invalid entities length");
                require(migrator.isEntity(vault), "Entity not exists");
            }
        }
    }
}
