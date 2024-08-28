// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {IVaultConfigurator} from "@symbiotic/core/interfaces/IVaultConfigurator.sol";

import {IAccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../vaults/IMellowVaultCompat.sol";

interface IMellowLRT {
    /**
     * @notice Perform delegate call to `to` with `data`.
     * @param to Targer addres.
     * @param data Calldta.
     * @return success Status of performed call.
     * @return response Data with response.
     */
    function delegateCall(address to, bytes calldata data)
        external
        returns (bool success, bytes memory response);

    /**
     * @notice Returns array of underlyinigTokens of the MellowLRT Vault.
     */
    function underlyingTokens() external view returns (address[] memory underlyinigTokens_);

    /**
     * @notice Returns array of configurator of the MellowLRT Vault.
     */
    function configurator() external view returns (IMellowLRTConfigurator);
}

interface IMellowLRTConfigurator {
    /**
     * @notice Returns array of validator of the MellowLRTC cnfigurator.
     */
    function validator() external view returns (IMellowLRTValidator);
}

interface IMellowLRTValidator {
    /**
     * @notice Checks whether `user` has permission to call function with selector `signature` of `contractAddress`.
     * @param user User address.
     * @param contractAddress Contract address.
     * @param signature Function selector.
     */
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

    /**
     * @notice Returns address of the Vault.
     */
    function vault() external view returns (address);

    /**
     * @notice Returns address of the Bond module.
     */
    function bondModule() external view returns (address);

    /**
     * @notice Sets specific `data` for `token`.
     */
    function setData(address token, Data[] memory data) external;

    /**
     * @notice Process all pending withdrawals.
     */
    function processAll() external;

    /**
     * @notice Returns specific data for the given `token`.
     */
    function tokenToData(address token) external view returns (bytes memory);
}

interface IDefaultBond {
    /**
     * @notice Returns address of underlyiing token.
     */
    function asset() external view returns (address);
}

interface IDefaultBondModule {
    /**
     * @notice Withdraw `amount` from `bond`.
     * @param bond Address of bond.
     * @param amount Amount of assets.
     */
    function withdraw(address bond, uint256 amount) external returns (uint256);
}

/**
 * @title IMigrator
 * @notice Perform migrate process from existing IMellowLRT Vaults into a new IMellowSymbioticVault.
 */
interface IMigrator {
    struct Parameters {
        address vault;
        address proxyAdmin;
        address proxyAdminOwner;
        address token;
        address bond;
        address defaultBondStrategy;
        IMellowSymbioticVault.InitParams initParams;
        IVaultConfigurator.InitParams symbioticVaultParams;
    }

    /// @notice Returns address of singleton.
    function singleton() external view returns (address);
    /// @notice Returns address of symbiotic VaultConfigurator.
    function symbioticVaultConfigurator() external view returns (address);
    /// @notice Returns address of admin of the Vault.
    function admin() external view returns (address);
    /// @notice Returns delay if migration process.
    function migrationDelay() external view returns (uint256);
    /// @notice Returns value of migration counter.
    function migrations() external view returns (uint256);
    
    /**
     * @notice Returns Parameters for staged migration with `index`.
     * @param index Index of migration.
     */
    function stagedMigrations(uint256 index) external view returns (Parameters memory);

    /**
     * @notice Stage specific migration.
     * @param defaultBondStrategy Address of defaultBondStrategy.
     * @param proxyAdmin Address of proxyAdmin.
     * @param proxyAdminOwner Address of proxyAdminOwner.
     * @param initParams Struct with initial parameters of the target Vault.
     * @param symbioticVaultParams Parameters of the target Simbiotic Vault.
     */
    function stageMigration(
        address defaultBondStrategy,
        address proxyAdmin,
        address proxyAdminOwner,
        IMellowSymbioticVault.InitParams memory initParams,
        IVaultConfigurator.InitParams memory symbioticVaultParams
    ) external returns (uint256 migrationIndex);

    /**
     * @notice Cancels migration process for the staged migrtion with `migrationIndex`.
     * @param migrationIndex Index of staged migration.
     */
    function cancelMigration(uint256 migrationIndex) external;

    /**
     * @notice Migrates staged migration with `migrationIndex`
     * @param migrationIndex Index of staged migration.
     */
    function migrate(uint256 migrationIndex) external;
}
