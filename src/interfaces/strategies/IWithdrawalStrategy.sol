// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/**
 * @title IWithdrawalStrategy
 * @notice Interface for a strategy that calculates withdrawal amounts for sub-vaults within a vault.
 * @dev Provides a method for determining the allocation of withdrawal amounts across sub-vaults.
 */
interface IWithdrawalStrategy {
    /**
     * @notice Represents the withdrawal data for a sub-vault.
     * @dev Includes details about claimable, pending, and staked assets for the sub-vault during withdrawal.
     * @param subvaultIndex The index of the sub-vault being considered for withdrawal.
     * @param claimable The amount of assets that can be claimed immediately from the sub-vault.
     * @param pending The amount of assets pending withdrawal from the sub-vault.
     * @param staked The amount of assets currently staked in the sub-vault.
     */
    struct WithdrawalData {
        uint256 subvaultIndex;
        uint256 claimable;
        uint256 pending;
        uint256 staked;
    }

    /**
     * @notice Calculates the withdrawal amounts for all sub-vaults in a given vault.
     * @dev This function determines how a specified amount of assets should be withdrawn from sub-vaults.
     * @param vault The address of the vault from which assets are being withdrawn.
     * @param amount The total amount of assets to be withdrawn.
     * @return subvaultsData An array of `WithdrawalData` structs, each containing withdrawal details for a sub-vault.
     */
    function calculateWithdrawalAmounts(address vault, uint256 amount)
        external
        view
        returns (WithdrawalData[] memory subvaultsData);
}
