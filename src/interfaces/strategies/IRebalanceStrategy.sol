// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/**
 * @title IRebalanceStrategy
 * @notice Interface for a strategy that calculates rebalance amounts for sub-vaults within a vault.
 * @dev Provides a method for determining deposit, claimable, and staked amounts for rebalancing.
 */
interface IRebalanceStrategy {
    /**
     * @notice Represents the rebalance data for a sub-vault.
     * @dev Includes details about deposits, claimable assets, and staked assets for the sub-vault.
     * @param subvaultIndex The index of the sub-vault being rebalanced.
     * @param deposit The amount of assets to be deposited into the sub-vault during rebalancing.
     * @param claimable The amount of assets that can be claimed from the sub-vault.
     * @param staked The amount of assets currently staked in the sub-vault.
     */
    struct RebalanceData {
        uint256 subvaultIndex;
        uint256 deposit;
        uint256 claimable;
        uint256 staked;
    }

    /**
     * @notice Calculates the rebalance amounts for all sub-vaults in a given vault.
     * @dev This function determines the allocation of assets for rebalancing based on the strategy's logic.
     * @param vault The address of the vault for which rebalance amounts are being calculated.
     * @return subvaultsData An array of `RebalanceData` structs, each containing rebalance details for a sub-vault.
     */
    function calculateRebalanceAmounts(address vault)
        external
        view
        returns (RebalanceData[] memory subvaultsData);
}
