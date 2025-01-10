// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/**
 * @title IIsolatedEigenLayerVaultFactory
 * @notice Interface for a factory that manages the creation and tracking of isolated EigenLayer vaults.
 * @dev This factory is responsible for creating isolated vaults and associated withdrawal queues,
 *      as well as managing mappings and key derivations for vault instances.
 */
interface IIsolatedEigenLayerVaultFactory {
    /**
     * @notice Data structure defining the properties of an isolated vault.
     * @dev Includes the owner, operator, strategy, and withdrawal queue addresses.
     * @param owner The address of the owner of the isolated vault.
     * @param operator The address of the operator managing the strategy.
     * @param strategy The address of the strategy associated with the isolated vault.
     * @param withdrawalQueue The address of the withdrawal queue associated with the isolated vault.
     */
    struct Data {
        address owner;
        address operator;
        address strategy;
        address withdrawalQueue;
    }

    /**
     * @notice Returns the address of the delegation contract used by the factory.
     * returns the address of the delegation contract.
     */
    function delegation() external view returns (address);

    /**
     * @notice Returns the address of the claimer contract used by the factory.
     * returns the address of the claimer contract.
     */
    function claimer() external view returns (address);

    /**
     * @notice Retrieves the details of an isolated vault instance by its address.
     * @param isolatedVault The address of the isolated vault.
     * @return owner The owner of the isolated vault.
     * @return operator The operator managing the strategy for the isolated vault.
     * @return strategy The strategy address associated with the isolated vault.
     * @return withdrawalQueue The withdrawal queue associated with the isolated vault.
     */
    function instances(address isolatedVault)
        external
        view
        returns (address owner, address operator, address strategy, address withdrawalQueue);

    /**
     * @notice Retrieves the address of an isolated vault using its unique key.
     * @param key The unique key representing the isolated vault (generated via `key` function).
     * returns the address of the isolated vault corresponding to the provided key.
     */
    function isolatedVaults(bytes32 key) external view returns (address);

    /**
     * @notice Derives a unique key for an isolated vault based on its owner, operator, and strategy.
     * @param owner The owner of the isolated vault.
     * @param operator The operator managing the strategy for the isolated vault.
     * @param strategy The strategy address associated with the isolated vault.
     * returns the derived key as a `bytes32` value.
     */
    function key(address owner, address operator, address strategy)
        external
        view
        returns (bytes32);

    /**
     * @notice Creates a new isolated vault and its withdrawal queue, or retrieves an existing one.
     * @param owner The owner of the isolated vault.
     * @param operator The operator managing the strategy for the isolated vault.
     * @param strategy The strategy address associated with the isolated vault.
     * @param data Additional initialization data for the isolated vault.
     * @return isolatedVault The address of the created or retrieved isolated vault.
     * @return withdrawalQueue The address of the associated withdrawal queue.
     */
    function getOrCreate(address owner, address operator, address strategy, bytes calldata data)
        external
        returns (address isolatedVault, address withdrawalQueue);
}
