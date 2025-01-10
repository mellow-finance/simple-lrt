// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IProtocolAdapter} from "../adapters/IProtocolAdapter.sol";
import {IWithdrawalQueue} from "../queues/IWithdrawalQueue.sol";
import {IDepositStrategy} from "../strategies/IDepositStrategy.sol";
import {IRebalanceStrategy} from "../strategies/IRebalanceStrategy.sol";
import {IWithdrawalStrategy} from "../strategies/IWithdrawalStrategy.sol";
import {IDefaultCollateral} from "../tokens/IDefaultCollateral.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    ERC4626Upgradeable,
    IERC4626
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title IMultiVaultStorage
 * @notice Interface for managing the storage and configuration of a multi-vault system.
 * @dev Provides definitions for storage structures, enums, functions, and events related to sub-vaults,
 *      strategies, adapters, and reward management.
 */
interface IMultiVaultStorage {
    /**
     * @notice Enum representing the protocol type of a sub-vault.
     * @dev Defines the protocols supported by the multi-vault system.
     * @param SYMBIOTIC Represents a symbiotic protocol.
     * @param EIGEN_LAYER Represents the EigenLayer protocol.
     * @param ERC4626 Represents an ERC4626-based protocol.
     */
    enum Protocol {
        SYMBIOTIC,
        EIGEN_LAYER,
        ERC4626
    }

    /**
     * @notice Structure representing a sub-vault's configuration.
     * @param protocol The protocol type of the sub-vault.
     * @param vault The address of the sub-vault.
     * @param withdrawalQueue The address of the withdrawal queue associated with the sub-vault.
     */
    struct Subvault {
        Protocol protocol;
        address vault;
        address withdrawalQueue;
    }

    /**
     * @notice Structure representing reward data for a specific farm.
     * @param distributionFarm The address of the distribution farm.
     * @param curatorTreasury The address of the curator's treasury.
     * @param token The address of the reward token.
     * @param curatorFeeD6 The curator's fee in parts per million (6 decimals).
     * @param protocol The protocol type associated with the reward.
     * @param data Additional encoded reward-related data.
     */
    struct RewardData {
        address distributionFarm;
        address curatorTreasury;
        address token;
        uint256 curatorFeeD6;
        Protocol protocol;
        bytes data;
    }

    /**
     * @notice Structure representing the overall storage configuration of the multi-vault.
     * @param depositStrategy The address of the deposit strategy.
     * @param withdrawalStrategy The address of the withdrawal strategy.
     * @param rebalanceStrategy The address of the rebalance strategy.
     * @param subvaults An array of all configured sub-vaults.
     * @param indexOfSubvault A mapping from sub-vault addresses to their indices.
     * @param rewardData A mapping from farm IDs to their associated reward data.
     * @param farmIds A set of all farm IDs.
     * @param defaultCollateral The address of the default collateral contract.
     * @param symbioticAdapter The address of the symbiotic adapter.
     * @param eigenLayerAdapter The address of the EigenLayer adapter.
     * @param erc4626Adapter The address of the ERC4626 adapter.
     * @param _gap Reserved storage slots for future upgrades.
     */
    struct MultiStorage {
        address depositStrategy;
        address withdrawalStrategy;
        address rebalanceStrategy;
        Subvault[] subvaults;
        mapping(address subvault => uint256 index) indexOfSubvault;
        mapping(uint256 id => RewardData) rewardData;
        EnumerableSet.UintSet farmIds;
        address defaultCollateral;
        address symbioticAdapter;
        address eigenLayerAdapter;
        address erc4626Adapter;
        bytes32[16] _gap;
    }

    // Function documentation
    /**
     * @notice Returns the total number of sub-vaults.
     * returns the number of sub-vaults.
     */
    function subvaultsCount() external view returns (uint256);

    /**
     * @notice Retrieves the sub-vault at the specified index.
     * @param index The index of the sub-vault.
     * returns the `Subvault` structure for the specified index.
     */
    function subvaultAt(uint256 index) external view returns (Subvault memory);

    /**
     * @notice Gets the index of a specific sub-vault.
     * @param subvault The address of the sub-vault.
     * returns the index of the sub-vault.
     */
    function indexOfSubvault(address subvault) external view returns (uint256);

    /**
     * @notice Retrieves the list of all farm IDs.
     * returns an array of farm IDs.
     */
    function farmIds() external view returns (uint256[] memory);

    /**
     * @notice Returns the total number of farms.
     * returns the count of farms.
     */
    function farmCount() external view returns (uint256);

    /**
     * @notice Retrieves the farm ID at the specified index.
     * @param index The index of the farm.
     * returns the farm ID.
     */
    function farmIdAt(uint256 index) external view returns (uint256);

    /**
     * @notice Checks if a specific farm ID exists.
     * @param farmId The ID of the farm.
     * @return True if the farm ID exists, false otherwise.
     */
    function farmIdsContains(uint256 farmId) external view returns (bool);

    /**
     * @notice Retrieves the default collateral contract.
     * returns the address of the default collateral contract.
     */
    function defaultCollateral() external view returns (IDefaultCollateral);

    /**
     * @notice Retrieves the deposit strategy contract.
     * returns the address of the deposit strategy contract.
     */
    function depositStrategy() external view returns (IDepositStrategy);

    /**
     * @notice Retrieves the withdrawal strategy contract.
     * returns the address of the withdrawal strategy contract.
     */
    function withdrawalStrategy() external view returns (IWithdrawalStrategy);

    /**
     * @notice Retrieves the rebalance strategy contract.
     * returns the address of the rebalance strategy contract.
     */
    function rebalanceStrategy() external view returns (IRebalanceStrategy);

    /**
     * @notice Retrieves the EigenLayer adapter contract.
     * returns the address of the EigenLayer adapter contract.
     */
    function eigenLayerAdapter() external view returns (IProtocolAdapter);

    /**
     * @notice Retrieves the symbiotic adapter contract.
     * returns the address of the symbiotic adapter contract.
     */
    function symbioticAdapter() external view returns (IProtocolAdapter);

    /**
     * @notice Retrieves the ERC4626 adapter contract.
     * returns the address of the ERC4626 adapter contract.
     */
    function erc4626Adapter() external view returns (IProtocolAdapter);

    /**
     * @notice Retrieves the adapter for a specific protocol.
     * @param protocol The protocol type.
     * returns the address of the protocol adapter.
     */
    function adapterOf(Protocol protocol) external view returns (IProtocolAdapter);

    /**
     * @notice Retrieves the reward data for a specific farm ID.
     * @param farmId The ID of the farm.
     * returns the `RewardData` structure associated with the farm ID.
     */
    function rewardData(uint256 farmId) external view returns (RewardData memory);

    // Event documentation
    event SubvaultAdded(
        address indexed subvault, address withdrawalQueue, Protocol protocol, uint256 subvaultIndex
    );

    /**
     * @notice Emitted when a sub-vault is removed from the vault.
     * @param subvault The address of the removed sub-vault.
     * @param subvaultIndex The index of the removed sub-vault.
     */
    event SubvaultRemoved(address indexed subvault, uint256 subvaultIndex);

    /**
     * @notice Emitted when the index of a sub-vault is changed.
     * @param subvault The address of the sub-vault whose index was changed.
     * @param oldIndex The old index of the sub-vault.
     * @param newIndex The new index of the sub-vault.
     */
    event SubvaultIndexChanged(address indexed subvault, uint256 oldIndex, uint256 newIndex);

    /**
     * @notice Emitted when reward data for a specific farm is removed.
     * @param farmId The ID of the farm whose reward data was removed.
     */
    event RewardDataRemoved(uint256 indexed farmId);

    /**
     * @notice Emitted when reward data is set for a specific farm.
     * @param farmId The ID of the farm.
     * @param data The new reward data associated with the farm.
     */
    event RewardDataSet(uint256 indexed farmId, RewardData data);

    /**
     * @notice Emitted when the default collateral contract is set.
     * @param defaultCollateral The address of the new default collateral contract.
     */
    event DefaultCollateralSet(address indexed defaultCollateral);

    /**
     * @notice Emitted when the deposit strategy contract is set.
     * @param depositStrategy The address of the new deposit strategy contract.
     */
    event DepositStrategySet(address indexed depositStrategy);

    /**
     * @notice Emitted when the withdrawal strategy contract is set.
     * @param withdrawalStrategy The address of the new withdrawal strategy contract.
     */
    event WithdrawalStrategySet(address indexed withdrawalStrategy);

    /**
     * @notice Emitted when the rebalance strategy contract is set.
     * @param rebalanceStrategy The address of the new rebalance strategy contract.
     */
    event RebalanceStrategySet(address indexed rebalanceStrategy);

    /**
     * @notice Emitted when the symbiotic adapter is set.
     * @param symbioticAdapter The address of the new symbiotic adapter contract.
     */
    event SymbioticAdapterSet(address indexed symbioticAdapter);

    /**
     * @notice Emitted when the EigenLayer adapter is set.
     * @param eigenLayerAdapter The address of the new EigenLayer adapter contract.
     */
    event EigenLayerAdapterSet(address indexed eigenLayerAdapter);

    /**
     * @notice Emitted when the ERC4626 adapter is set.
     * @param erc4626Adapter The address of the new ERC4626 adapter contract.
     */
    event ERC4626AdapterSet(address indexed erc4626Adapter);
}
