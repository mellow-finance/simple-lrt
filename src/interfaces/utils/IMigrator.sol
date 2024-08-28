// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {IAccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../vaults/IMellowVaultCompat.sol";

interface IMellowLRT {
    function delegateCall(address to, bytes calldata data)
        external
        returns (bool success, bytes memory response);

    function underlyingTokens() external view returns (address[] memory underlyinigTokens_);

    function configurator() external view returns (IMellowLRTConfigurator);
}

interface IMellowLRTConfigurator {
    function validator() external view returns (IMellowLRTValidator);

    function maximalTotalSupply() external view returns (uint256);
}

interface IMellowLRTValidator {
    function hasPermission(address user, address contractAddress, bytes4 signature)
        external
        view
        returns (bool);
}

interface IDefaultBondStrategy {
    struct Data {
        address bond;
        uint256 ratioX96;
    }

    function vault() external view returns (address);

    function bondModule() external view returns (address);

    function setData(address token, Data[] memory data) external;

    function processAll() external;

    function tokenToData(address token) external view returns (bytes memory);
}

interface IDefaultBond {
    function asset() external view returns (address);
}

interface IDefaultBondModule {
    function withdraw(address bond, uint256 amount) external returns (uint256);
}

/**
 * @title IMigrator
 * @notice Interface for managing the migration of vault systems, including staging, canceling, processing migrations, and managing proxy admins.
 */
interface IMigrator {
    /**
     * @notice Struct to store parameters related to a migration.
     * @param vault The address of the vault being migrated.
     * @param proxyAdmin The address of the proxy admin managing the vault's proxy.
     * @param proxyAdminOwner The address of the owner of the proxy admin.
     * @param token The address of the token used by the vault.
     * @param bond The address of the bond associated with the vault.
     * @param defaultBondStrategy The address of the default bond strategy contract associated with the vault.
     */
    struct Parameters {
        address vault;
        address proxyAdmin;
        address proxyAdminOwner;
        address token;
        address bond;
        address defaultBondStrategy;
    }

    /**
     * @notice Returns the address of the migrator's singleton contract.
     * @return The address of the singleton contract.
     */
    function singleton() external view returns (address);

    /**
     * @notice Returns the address of the symbiotic vault configurator.
     * @return The address of the symbiotic vault configurator.
     */
    function symbioticVaultConfigurator() external view returns (address);

    /**
     * @notice Returns the address of the migrator's admin.
     * @return The address of the admin.
     */
    function admin() external view returns (address);

    /**
     * @notice Returns the delay period before a migration can be processed.
     * @return The migration delay in seconds.
     */
    function migrationDelay() external view returns (uint256);

    /**
     * @notice Returns the total number of migrations that have been staged.
     * @return The total number of migrations.
     */
    function migrations() external view returns (uint256);

    /**
     * @notice Returns the migration parameters for a given vault.
     * @param vault The address of the vault being migrated.
     * @return The migration parameters as a `Parameters` struct.
     */
    function migration(address vault) external view returns (Parameters memory);

    /**
     * @notice Returns the timestamp when a migration was staged for a given vault.
     * @param vault The address of the vault being migrated.
     * @return The timestamp of when the migration was staged.
     */
    function timestamps(address vault) external view returns (uint256);

    /**
     * @notice Returns the initialization parameters for a vault that is part of the migration process.
     * @param vault The address of the vault being migrated.
     * @return The initialization parameters as an `IMellowSymbioticVault.InitParams` struct.
     */
    function vaultInitParams(address vault)
        external
        view
        returns (IMellowSymbioticVault.InitParams memory);

    /**
     * @notice Stages a migration for a vault, storing the necessary migration parameters.
     * @param defaultBondStrategy The address of the default bond strategy contract.
     * @param vaultAdmin The address of the admin for the new vault.
     * @param proxyAdmin The address of the proxy admin managing the vault's proxy.
     * @param proxyAdminOwner The address of the new owner of the proxy admin.
     * @param symbioticVault The address of the symbiotic vault to which the migration is directed.
     */
    function stageMigration(
        address defaultBondStrategy,
        address vaultAdmin,
        address proxyAdmin,
        address proxyAdminOwner,
        address symbioticVault
    ) external;

    /**
     * @notice Cancels a staged migration for a vault.
     * @param vault The address of the vault whose migration is to be canceled.
     */
    function cancelMigration(address vault) external;

    /**
     * @notice Processes a staged migration for a vault, completing the migration process.
     * @param vault The address of the vault being migrated.
     */
    function migrate(address vault) external;
}
