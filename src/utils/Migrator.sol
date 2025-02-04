// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../adapters/SymbioticAdapter.sol";
import "../interfaces/vaults/IMellowSymbioticVault.sol";
import "../vaults/MultiVault.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract Migrator {
    mapping(address vault => bool) private _isEntity;
    address[] private _entities;

    struct MigrationData {
        address proxyAdminOwner;
        address vault;
        uint256 timestamp;
    }

    address public immutable simpleLrtFactory;
    address public immutable multiVaultSingleton;
    address public immutable strategy;
    address public immutable symbioticVaultFactory;
    address public immutable withdrawalQueueSingleton;
    uint256 public immutable migrationDelay;

    mapping(address proxyAdmin => MigrationData) public migrations;

    constructor(
        address simpleLrtFactory_,
        address multiVaultSingleton_,
        address strategy_,
        address symbioticVaultFactory_,
        address withdrawalQueueSingleton_,
        uint256 migrationDelay_
    ) {
        simpleLrtFactory = simpleLrtFactory_;
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
        if (_isEntity[vault]) {
            revert("Migrator: vault already migrated");
        }
        if (
            !Migrator(simpleLrtFactory).isEntity(vault)
                && IMellowSymbioticVault(vault).compatTotalSupply() != 0
        ) {
            revert("Migrator: previous migration is incomplete");
        }
        data = MigrationData({
            proxyAdminOwner: proxyAdminOwner,
            vault: vault,
            timestamp: block.timestamp + migrationDelay
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

    function executeMigration(ProxyAdmin proxyAdmin, address vaultAdmin) external {
        MigrationData memory data = migrations[address(proxyAdmin)];
        if (data.proxyAdminOwner != msg.sender) {
            revert("Migrator: sender not owner");
        }
        if (proxyAdmin.owner() != address(this)) {
            revert("Migrator: ownership not transferred to migrator");
        }
        if (data.timestamp > block.timestamp) {
            revert("Migrator: migration not ready");
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
                IMultiVault.initialize,
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
                        defaultCollateral: vault.symbioticCollateral(),
                        symbioticAdapter: address(symbioticAdapter),
                        eigenLayerAdapter: address(0),
                        erc4626Adapter: address(0)
                    })
                )
            )
        );

        MultiVault multiVault = MultiVault(address(vault));
        {
            multiVault.grantRole(multiVault.ADD_SUBVAULT_ROLE(), address(this));
            multiVault.addSubvault(symbioticVault, IMultiVaultStorage.Protocol.SYMBIOTIC);
            multiVault.renounceRole(multiVault.ADD_SUBVAULT_ROLE(), address(this));

            bytes32 DEFAULT_ADMIN_ROLE = multiVault.DEFAULT_ADMIN_ROLE();
            multiVault.renounceRole(DEFAULT_ADMIN_ROLE, address(this));
            if (
                !multiVault.hasRole(DEFAULT_ADMIN_ROLE, vaultAdmin)
                    || multiVault.getRoleMemberCount(DEFAULT_ADMIN_ROLE) != 1
            ) {
                revert("Migrator: invalid vault admin");
            }
        }
        proxyAdmin.transferOwnership(data.proxyAdminOwner);
        delete migrations[address(proxyAdmin)];

        _isEntity[address(vault)] = true;
        _entities.push(address(vault));

        emit MigrationExecuted(address(proxyAdmin), data);
    }

    function entities() external view returns (address[] memory) {
        return _entities;
    }

    function entitiesLength() external view returns (uint256) {
        return _entities.length;
    }

    function isEntity(address entity) public view returns (bool) {
        return _isEntity[entity];
    }

    function entityAt(uint256 index) external view returns (address) {
        return _entities[index];
    }

    event MigrationStaged(address indexed proxyAdmin, MigrationData data);
    event MigrationCancelled(address indexed proxyAdmin);
    event MigrationExecuted(address indexed proxyAdmin, MigrationData data);
}
