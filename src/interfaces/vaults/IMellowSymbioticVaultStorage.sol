// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IWithdrawalQueue} from "../utils/IWithdrawalQueue.sol";
import {IVault as ISymbioticVault} from "@symbiotic/core/interfaces/vault/IVault.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title IMellowSymbioticVaultStorage
 * @notice Interface for interacting with the storage of the Mellow Symbiotic Vault.
 * @dev This interface defines methods to manage farms and related vaults.
 */
interface IMellowSymbioticVaultStorage {
    /**
     * @notice Struct to store data related to a specific farm.
     * @param rewardToken The address of the reward token distributed by the farm.
     * @param symbioticFarm The address of the symbiotic farm contract.
     * @param distributionFarm The address of the distribution farm contract.
     * @param curatorTreasury The address of the curator's treasury receiving fees.
     * @param curatorFeeD6 The curator's fee, represented with 6 decimal places.
     */
    struct FarmData {
        address rewardToken;
        address symbioticFarm;
        address distributionFarm;
        address curatorTreasury;
        uint256 curatorFeeD6;
    }

    /**
     * @notice Struct to manage storage related to the symbiotic vault, withdrawal queue and farms.
     * @param symbioticVault The address of the associated symbiotic vault.
     * @param withdrawalQueue The withdrawal queue associated with the vault.
     * @param farmIds The set of farm IDs associated to this vault.
     * @param farms Mapping of farm IDs to their respective `FarmData`.
     */
    struct SymbioticStorage {
        ISymbioticVault symbioticVault;
        IWithdrawalQueue withdrawalQueue;
        EnumerableSet.UintSet farmIds;
        mapping(uint256 => FarmData) farms;
    }

    /**
     * @notice Returns the address of the associated Symbiotic Vault.
     * @return vault The address of the Symbiotic Vault.
     */
    function symbioticVault() external view returns (ISymbioticVault);

    /**
     * @notice Returns the address of the associated withdrawal queue.
     * @return queue The address of the withdrawal queue.
     */
    function withdrawalQueue() external view returns (IWithdrawalQueue);

    /**
     * @notice Returns an array of farm IDs associated to the Symbiotic Vault.
     * @return farmIds An array of farm IDs.
     */
    function symbioticFarmIds() external view returns (uint256[] memory);

    /**
     * @notice Returns the number of associated farms.
     * @return farmCount The count of associated farms.
     */
    function symbioticFarmCount() external view returns (uint256);

    /**
     * @notice Returns the farm ID at the given index.
     * @param index The index of the farm ID.
     * @return farmId The farm ID at the specified index.
     */
    function symbioticFarmIdAt(uint256 index) external view returns (uint256);

    /**
     * @notice Checks if the given `farmId` exists in the set of linked farms.
     * @param farmId The ID of the farm.
     * @return exists `true` if the farm ID exists, `false` otherwise.
     */
    function symbioticFarmsContains(uint256 farmId) external view returns (bool);

    /**
     * @notice Returns the `FarmData` associated with the given `farmId`.
     * @param farmId The ID of the farm.
     * @return data The `FarmData` struct for the specified farm.
     */
    function symbioticFarm(uint256 farmId) external view returns (FarmData memory);

    /**
     * @notice Emitted when a new symbiotic vault is set.
     * @param symbioticVault The address of the new symbiotic vault.
     * @param timestamp The time at which the symbiotic vault was set.
     */
    event SymbioticVaultSet(address symbioticVault, uint256 timestamp);

    /**
     * @notice Emitted when a new withdrawal queue is set.
     * @param withdrawalQueue The address of the new withdrawal queue.
     * @param timestamp The time at which the withdrawal queue was set.
     */
    event WithdrawalQueueSet(address withdrawalQueue, uint256 timestamp);

    /**
     * @notice Emitted when a new farm is set.
     * @param farmId The ID of the farm.
     * @param farmData The `FarmData` struct containing details of the farm.
     * @param timestamp The time at which the farm was set.
     */
    event FarmSet(uint256 farmId, FarmData farmData, uint256 timestamp);
}
