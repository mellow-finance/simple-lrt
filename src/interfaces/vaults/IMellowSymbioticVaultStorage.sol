// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IWithdrawalQueue} from "../utils/IWithdrawalQueue.sol";
import {IVault as ISymbioticVault} from "@symbiotic/core/interfaces/vault/IVault.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title IMellowSymbioticVaultStorage
 * @notice Interface defining intaraction with storage of the Vault.
 */
interface IMellowSymbioticVaultStorage {
    struct FarmData {
        address rewardToken;
        address symbioticFarm;
        address distributionFarm;
        address curatorTreasury;
        uint256 curatorFeeD6;
    }

    struct SymbioticStorage {
        ISymbioticVault symbioticVault;
        IWithdrawalQueue withdrawalQueue;
        EnumerableSet.UintSet farmIds;
        mapping(uint256 farmId => FarmData data) farms;
    }

    /**
     * @notice Returns address of the underlying Symbiotic Vault.
     */
    function symbioticVault() external view returns (ISymbioticVault);

    /**
     * @notice Returns address of the linked withdrawal queue.
     */
    function withdrawalQueue() external view returns (IWithdrawalQueue);

    /**
     * @notice Returns array of the linked farm ids.
     */
    function symbioticFarmIds() external view returns (uint256[] memory);

    /**
     * @notice Returns count of linked Farms.
     */
    function symbioticFarmCount() external view returns (uint256);

    /**
     * @notice Returns address of the linked withdrawal queue.
     */
    function symbioticFarmIdAt(uint256 index) external view returns (uint256);

    /**
     * @notice Returns whether the Vault has `farmId`.
     */
    function symbioticFarmsContains(uint256 farmId) external view returns (bool);

    /**
     * @notice Returns FarmData by `farmId`.
     */
    function symbioticFarm(uint256 farmId) external view returns (FarmData memory);

    event SymbioticVaultSet(address symbioticVault, uint256 timestamp);

    event WithdrawalQueueSet(address withdrawalQueue, uint256 timestamp);

    event FarmSet(uint256 farmId, FarmData farmData, uint256 timestamp);
}
