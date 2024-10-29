// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../scripts/mainnet/MigrationDeploy.sol";
import "../BaseTest.sol";
import "./AcceptanceMigrationRunner.sol";

import "../Constants.sol";

contract AcceptanceMigrationTest is AcceptanceMigrationRunner, BaseTest {
    function testAcceptanceMigrationOnlyDeployment() external {
        address symbioticVault = symbioticHelper.createNewSymbioticVault(
            SymbioticHelper.CreationParams({
                vaultOwner: makeAddr("symbioticVaultOwner"),
                vaultAdmin: makeAddr("symbioticVaultAdmin"),
                epochDuration: 7 days,
                asset: Constants.WSTETH(),
                isDepositLimit: false,
                depositLimit: 0
            })
        );

        MigrationDeploy.MigrationDeployParams memory deployParams = MigrationDeploy
            .MigrationDeployParams({
            migrator: address(0),
            migratorAdmin: address(this),
            migratorDelay: 1 days,
            vault: 0x956310119f96fD52590aed4ff213718Ea61d1247,
            singleton: address(0),
            singletonName: "MellowVaultCompat",
            singletonVersion: 1,
            defaultBondStrategy: 0x8b9B55BA5D48D4De08915D14bC561Db30006A307,
            vaultAdmin: 0x2C5f98743e4Cb30d8d65e30B8cd748967D7A051e,
            proxyAdmin: 0xd67241F8FA670D1eaEd14b7A17B82819087AE86d,
            proxyAdminOwner: 0x3995c5a3A74f3B3049fD5DA7C7D7BaB0b581A6e1,
            symbioticVault: symbioticVault
        });

        // DEPLOY:

        deployParams = MigrationDeploy.commonDeploy(deployParams);
        vm.startPrank(deployParams.vaultAdmin);
        bytes32 OPERATOR = keccak256("operator");
        bytes32 ADMIN_DELEGATE_ROLE = keccak256("admin_delegate");
        if (
            !IAccessControlEnumerable(deployParams.defaultBondStrategy).hasRole(
                ADMIN_DELEGATE_ROLE, deployParams.vaultAdmin
            )
        ) {
            IAccessControlEnumerable(deployParams.defaultBondStrategy).grantRole(
                ADMIN_DELEGATE_ROLE, address(deployParams.vaultAdmin)
            );
        }
        IAccessControlEnumerable(deployParams.defaultBondStrategy).grantRole(
            OPERATOR, address(deployParams.migrator)
        );
        vm.stopPrank();

        vm.startPrank(deployParams.migratorAdmin);
        MigrationDeploy.deployStage(deployParams);
        vm.stopPrank();

        vm.startPrank(deployParams.proxyAdminOwner);
        ProxyAdmin(deployParams.proxyAdmin).transferOwnership(address(deployParams.migrator));
        skip(deployParams.migratorDelay);
        vm.stopPrank();

        vm.startPrank(deployParams.migratorAdmin);
        (IMellowSymbioticVault vault,) = MigrationDeploy.deployCommit(deployParams);
        vm.stopPrank();

        // ACCEPTANCE TEST:
        runAcceptance(
            MellowVaultCompat(address(vault)),
            deployParams,
            AcceptanceMigrationRunner.TestParams({isDuringDeployment: true})
        );
    }
}
