// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {IWithdrawalQueue} from "../utils/IWithdrawalQueue.sol";
import {IMellowSymbioticVault} from "./IMellowSymbioticVault.sol";

/**
 * @title IMellowSymbioticVaultFactory
 * @notice Interface for the singleton factory that deploys new Mellow Symbiotic Vaults.
 * @dev This factory is responsible for creating and initializing vaults and their associated withdrawal queues.
 */
interface IMellowSymbioticVaultFactory {
    /**
     * @notice Struct to store initialization parameters for creating a new vault.
     * @param proxyAdmin The address of the proxy admin.
     * @param limit The maximum asset limit for deposits.
     * @param symbioticCollateral The address of the Symbiotic Collateral contract.
     * @param symbioticVault The address of the underlying Symbiotic Vault.
     * @param admin The address of the admin who manages the vault.
     * @param depositPause Flag to indicate whether deposits are initially paused.
     * @param withdrawalPause Flag to indicate whether withdrawals are initially paused.
     * @param depositWhitelist Flag to indicate whether a deposit whitelist is enabled.
     * @param name The name of the vault token.
     * @param symbol The symbol of the vault token.
     */
    struct InitParams {
        address proxyAdmin;
        uint256 limit;
        address symbioticCollateral;
        address symbioticVault;
        address admin;
        bool depositPause;
        bool withdrawalPause;
        bool depositWhitelist;
        string name;
        string symbol;
    }

    /**
     * @notice Returns the address of the MellowSymbioticVault singleton contract.
     * @return address The address of the singleton.
     */
    function singleton() external view returns (address);

    /**
     * @notice Deploys a new Mellow Symbiotic Vault with the provided initialization parameters.
     * @param initParams The initialization parameters for the new vault.
     * @return vault The address of the newly deployed Mellow Symbiotic Vault.
     * @return withdrawalQueue The address of the newly deployed Withdrawal Queue associated with the vault.
     *
     * @custom:effects
     * - Deploys a new vault and withdrawal queue.
     * - Initializes the vault with the provided parameters.
     * - Emits an `EntityCreated` event upon successful creation.
     */
    function create(InitParams memory initParams)
        external
        returns (IMellowSymbioticVault vault, IWithdrawalQueue withdrawalQueue);

    /**
     * @notice Returns the addresses of all deployed vaults by the factory.
     * @return vaultAddresses An array of addresses representing the deployed vaults.
     */
    function entities() external view returns (address[] memory);

    /**
     * @notice Returns the total number of deployed vaults.
     * @return count The number of vaults deployed by the factory.
     */
    function entitiesLength() external view returns (uint256);

    /**
     * @notice Checks whether the provided address corresponds to a vault deployed by the factory.
     * @param entity The address to check.
     * @return isDeployed `true` if the address is a deployed vault, `false` otherwise.
     */
    function isEntity(address entity) external view returns (bool);

    /**
     * @notice Returns the address of the vault deployed at the specified index.
     * @param index The index of the vault in the array of deployed vaults.
     * @return vaultAddress The address of the vault at the specified index.
     */
    function entityAt(uint256 index) external view returns (address);

    /**
     * @notice Emitted when a new vault and withdrawal queue are successfully created.
     * @param vault The address of the newly created vault.
     * @param timestamp The timestamp of when the vault was created.
     */
    event EntityCreated(address indexed vault, uint256 timestamp);
}
