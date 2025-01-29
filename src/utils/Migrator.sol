// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/vaults/IMellowSymbioticVault.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../adapters/SymbioticAdapter.sol";
import "../vaults/MultiVault.sol";

contract Migrator {
    struct MigrationData {
        address proxyAdminOwner;
        address vault;
        uint256 timestamp;
    }

    address public immutable multiVaultSingleton;
    address public immutable strategy;
    address public immutable symbioticVaultFactory;
    address public immutable withdrawalQueueSingleton;
    uint256 public immutable migrationDelay;

    mapping(address proxyAdmin => MigrationData) public migrations;

    constructor(
        address multiVaultSingleton_,
        address strategy_,
        address symbioticVaultFactory_,
        address withdrawalQueueSingleton_,
        uint256 migrationDelay_
    ) {
        multiVaultSingleton = multiVaultSingleton_;
        strategy = strategy_;
        symbioticVaultFactory = symbioticVaultFactory_;
        withdrawalQueueSingleton = withdrawalQueueSingleton_;
        migrationDelay = migrationDelay_;
    }

    function stageMigration(ProxyAdmin proxyAdmin, address vault)
        external
        returns (MigrationData memory data)
    {
        address proxyAdminOwner = proxyAdmin.owner();
        if (msg.sender != proxyAdminOwner) {
            revert("Migrator: sender not owner");
        }
        if (migrations[address(proxyAdmin)].timestamp != 0) {
            revert("Migrator: vault migration already staged");
        }
        data = MigrationData({
            proxyAdminOwner: proxyAdminOwner,
            vault: vault,
            timestamp: block.timestamp
        });
        migrations[address(proxyAdmin)] = data;
        emit MigrationStaged(address(proxyAdmin), data);
    }

    function cancelMigration(ProxyAdmin proxyAdmin) external {
        address proxyAdminOwner = migrations[address(proxyAdmin)].proxyAdminOwner;
        if (msg.sender != proxyAdminOwner) {
            revert("Migrator: sender not owner");
        }
        if (proxyAdmin.owner() == address(this)) {
            proxyAdmin.transferOwnership(proxyAdminOwner);
        }
        delete migrations[address(proxyAdmin)];
        emit MigrationCancelled(address(proxyAdmin));
    }

    function migrate(ProxyAdmin proxyAdmin) external {
        MigrationData memory data = migrations[address(proxyAdmin)];
        if (data.proxyAdminOwner != msg.sender) {
            revert("Migrator: sender not owner");
        }
        if (proxyAdmin.owner() != address(this)) {
            revert("Migrator: ownership not transferred to migrator");
        }
        IMellowSymbioticVault vault = IMellowSymbioticVault(data.vault);
        address symbioticVault = vault.symbioticVault();
        SymbioticAdapter symbioticAdapter = new SymbioticAdapter{
            salt: bytes32(bytes20(address(vault)))
        }(address(vault), symbioticVaultFactory, withdrawalQueueSingleton, data.proxyAdminOwner);
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(vault)),
            multiVaultSingleton,
            abi.encodeCall(
                MultiVault.initialize,
                (
                    IMultiVault.InitParams({
                        admin: address(this),
                        limit: vault.limit(),
                        depositPause: vault.depositPause(),
                        withdrawalPause: vault.withdrawalPause(),
                        depositWhitelist: vault.depositWhitelist(),
                        asset: vault.asset(),
                        name: vault.name(),
                        symbol: vault.symbol(),
                        depositStrategy: address(strategy),
                        withdrawalStrategy: address(strategy),
                        rebalanceStrategy: address(strategy),
                        defaultCollateral: vault.defaultCollateral(),
                        symbioticAdapter: address(symbioticAdapter),
                        eigenLayerAdapter: address(0),
                        erc4626Adapter: address(0)
                    })
                )
            )
        );

        MultiVault multiVault = MultiVault(address(vault));
        multiVault.grantRole(multiVault.ADD_SUBVAULT_ROLE(), address(this));
        multiVault.addSubvault(symbioticVault, IMultiVaultStorage.Protocol.SYMBIOTIC);
        multiVault.renounceRole(multiVault.ADD_SUBVAULT_ROLE(), address(this));
        multiVault.renounceRole(multiVault.DEFAULT_ADMIN_ROLE(), address(this));
        delete migrations[address(proxyAdmin)];

        emit MigrationExecuted(address(proxyAdmin), data);
    }

    event MigrationStaged(address indexed proxyAdmin, MigrationData data);
    event MigrationCancelled(address indexed proxyAdmin);
    event MigrationExecuted(address indexed proxyAdmin, MigrationData data);
}
