// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../../src/MellowSymbioticVault.sol";
import "../../src/MellowSymbioticVaultFactory.sol";
import "../../src/MellowVaultCompat.sol";

import "../../src/Migrator.sol";
import "../../src/VaultControl.sol";

import "./Permissions.sol";

/// @notice this is a test script, all actions will be processed on behalf of permissioned accounts.
library MigrationDeploy {
    struct MigrationDeployParams {
        address migrator;
        address migratorAdmin;
        uint256 migratorDelay;
        address vault;
        address singleton;
        bytes32 singletonName;
        uint256 singletonVersion;
        address defaultBondStrategy;
        address vaultAdmin;
        address proxyAdmin;
        address proxyAdminOwner;
        address symbioticVault;
    }

    function commonDeploy(MigrationDeployParams memory $)
        public
        returns (MigrationDeployParams memory)
    {
        if ($.migrator == address(0)) {
            if ($.singleton == address(0)) {
                require($.singletonName != bytes32(0), "MigrationDeploy: singletonName is required");
                $.singleton = address(new MellowVaultCompat($.singletonName, $.singletonVersion));
            }
            require($.migratorDelay > 0, "MigrationDeploy: migratorDelay is required");
            require($.migratorAdmin != address(0), "MigrationDeploy: migratorAdmin is required");
            $.migrator = address(new Migrator($.singleton, $.migratorAdmin, $.migratorDelay));
        }
        return $;
    }

    function deployStage(MigrationDeployParams memory $) public {
        $ = commonDeploy($);

        require(
            $.migratorAdmin == address(this),
            "MigrationDeploy: migratorAdmin must be MigrationDeploy.sol"
        );

        Migrator($.migrator).stageMigration(
            $.defaultBondStrategy, $.vaultAdmin, $.proxyAdmin, $.symbioticVault
        );
    }

    function deployCommit(MigrationDeployParams memory $)
        public
        returns (IMellowSymbioticVault vault, IWithdrawalQueue withdrawalQueue)
    {
        Migrator($.migrator).migrate($.vault);
        vault = IMellowSymbioticVault($.vault);
        withdrawalQueue = vault.withdrawalQueue();
    }
}
