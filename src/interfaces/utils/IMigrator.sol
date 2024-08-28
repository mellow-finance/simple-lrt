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
 * @notice Interface for managing migrations between vault systems, including staging, canceling, and processing migrations.
 */
interface IMigrator {
    /**
     * @notice Struct to store parameters for migration.
     * @param vault The address of the vault.
     * @param proxyAdmin The address of the proxy admin.
     * @param proxyAdminOwner The address of the proxy admin owner.
     * @param token The address of the token of the vault.
     * @param bond The address of the bond.
     * @param defaultBondStrategy The address of the default bond strategy.
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
     * @notice Returns the address of the MellowVaultCompat singleton contract.
     * @return The singleton address.
     */
    function singleton() external view returns (address);

    /**
     * @notice Returns the address of the symbiotic vault configurator.
     * @return The symbiotic vault configurator address.
     */
    function symbioticVaultConfigurator() external view returns (address);

    /**
     * @notice Returns the address of the admin.
     * @return The admin address.
     */
    function admin() external view returns (address);

    /**
     * @notice Returns the delay before a migration can be processed.
     * @return The migration delay in seconds.
     */
    function migrationDelay() external view returns (uint256);

    /**
     * @notice Returns the total number of migrations staged by the migrator.
     * @return The total number of migrations.
     */
    function migrations() external view returns (uint256);

    /**
     * @notice Returns details of a migration at a given index.
     * @param index The index of the migration.
     * @return vault The vault address.
     * @return proxyAdmin The proxy admin address.
     * @return proxyAdminOwner The proxy admin owner address.
     * @return token The token address.
     * @return bond The bond address.
     * @return defaultBondStrategy The default bond strategy address.
     */
    function migration(uint256 index)
        external
        view
        returns (
            address vault,
            address proxyAdmin,
            address proxyAdminOwner,
            address token,
            address bond,
            address defaultBondStrategy
        );

    /**
     * @notice Stages a migration with the provided parameters.
     * @param defaultBondStrategy The default bond strategy address.
     * @param vaultAdmin The vault admin address.
     * @param proxyAdmin The proxy admin address.
     * @param proxyAdminOwner The proxy admin owner address.
     * @param symbioticVault The symbiotic vault address.
     * @return migrationIndex The index of the newly staged migration.
     */
    function stageMigration(
        address defaultBondStrategy,
        address vaultAdmin,
        address proxyAdmin,
        address proxyAdminOwner,
        address symbioticVault
    ) external returns (uint256 migrationIndex);

    /**
     * @notice Cancels a migration that was previously staged.
     * @param migrationIndex The index of the migration to cancel.
     */
    function cancelMigration(uint256 migrationIndex) external;

    /**
     * @notice Executes a migration that has been staged.
     * @param migrationIndex The index of the migration to execute.
     */
    function migrate(uint256 migrationIndex) external;
}
