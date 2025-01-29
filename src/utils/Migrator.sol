// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/vaults/IMellowSymbioticVault.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../adapters/SymbioticAdapter.sol";
import "../vaults/MultiVault.sol";

contract Migrator {
    address public immutable multiVaultSingleton;
    address public immutable strategy;
    address public immutable symbioticVaultFactory;
    address public immutable withdrawalQueueSingleton;

    struct Migration {
        address proxyAdmin;
        address vaultAdmin;
        address vaultProxyAdmin;
        uint256 timestamp;
    }

    mapping(address vault => Migration) public migrations;

    constructor(
        address multiVaultSingleton_,
        address strategy_,
        address symbioticVaultFactory_,
        address withdrawalQueueSingleton_
    ) {
        multiVaultSingleton = multiVaultSingleton_;
        strategy = strategy_;
        symbioticVaultFactory = symbioticVaultFactory_;
        withdrawalQueueSingleton = withdrawalQueueSingleton_;
    }

    function stageMigration(address vault, address proxyAdmin, address vaultAdmin) external {
    
        address proxyAdminOwner = proxyAdmin.owner();
        if (proxyAdminOwners[vault] != address(0)) {
            revert("Migrator: vault migration already staged");
        }
        if (msg.sender != proxyAdminOwner) {
            revert("Migrator: sender not owner");
        }
        proxyAdminOwners[vault] = proxyAdminOwner;
    }

    function cancelMigration(address vault) external {
        address proxyAdminOwner = proxyAdminOwners[vault];
        if (msg.sender != proxyAdminOwner) {
            revert("Migrator: sender not owner");
        }
        if (proxyAdmin.owner() == address(this)) {
            proxyAdmin.transferOwnership(proxyAdminOwner);
        }
        delete proxyAdminOwners[vault];
    }

    function migrate(address vault, address vaultAdmin) external {
        address proxyAdminOwner = proxyAdminOwners[vault];
        if (proxyAdminOwner == address(0)) {
            revert("Migrator: vault migration not staged");
        }
        if (proxyAdminOwner != msg.sender) {
            revert("Migrator: sender not owner");
        }
        ProxyAdmin proxyAdmin = getProxyAdmin(vault);
        if (proxyAdmin.owner() != address(this)) {
            revert("Migrator: ownership not transferred to migrator");
        }

        address symbioticVault = IMellowSymbioticVault(vault).symbioticVault();

        SymbioticAdapter symbioticAdapter = new SymbioticAdapter{salt: bytes32(bytes20(vault))}(
            vault, symbioticVaultFactory, withdrawalQueueSingleton, proxyAdminOwner
        );
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(vault),
            multiVaultSingleton,
            abi.encodeCall(
                MultiVault.initialize,
                (
                    IMultiVault.InitParams({
                        admin: address(this),
                        limit: IMellowSymbioticVault(vault).limit(),
                        depositPause: IMellowSymbioticVault(vault).depositPause(),
                        withdrawalPause: IMellowSymbioticVault(vault).withdrawalPause(),
                        depositWhitelist: IMellowSymbioticVault(vault).depositWhitelist(),
                        asset: IMellowSymbioticVault(vault).asset(),
                        name: IMellowSymbioticVault(vault).name(),
                        symbol: IMellowSymbioticVault(vault).symbol(),
                        depositStrategy: address(strategy),
                        withdrawalStrategy: address(strategy),
                        rebalanceStrategy: address(strategy),
                        defaultCollateral: IMellowSymbioticVault(vault).defaultCollateral(),
                        symbioticAdapter: address(symbioticAdapter),
                        eigenLayerAdapter: address(0),
                        erc4626Adapter: address(0)
                    })
                )
            )
        );

        MultiVault multiVault = MultiVault(vault);
        multiVault.grantRole(multiVault.ADD_SUBVAULT_ROLE(), address(this));
        multiVault.addSubvault(symbioticVault, IMultiVaultStorage.Protocol.SYMBIOTIC);
        multiVault.grantRole(multiVault.DEFAULT_ADMIN_ROLE(), vaultAdmin);
        multiVault.renounceRole(multiVault.ADD_SUBVAULT_ROLE(), address(this));
        multiVault.renounceRole(multiVault.DEFAULT_ADMIN_ROLE(), address(this));
    }
}
