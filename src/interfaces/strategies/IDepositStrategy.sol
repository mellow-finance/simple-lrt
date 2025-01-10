// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/**
 * @title IDepositStrategy
 * @notice Interface for defining deposit strategies across sub-vaults within a vault system.
 * @dev Provides a method to calculate the allocation of deposit amounts among sub-vaults.
 */
interface IDepositStrategy {
    /**
     * @notice Structure representing the deposit data for a sub-vault.
     * @dev Specifies the sub-vault index and the deposit amount allocated to it.
     * @param subvaultIndex The index of the sub-vault to which the deposit is allocated.
     * @param deposit The amount of assets to deposit into the specified sub-vault.
     */
    struct DepositData {
        uint256 subvaultIndex;
        uint256 deposit;
    }

    /**
     * @notice Calculates the allocation of deposit amounts across sub-vaults for a given vault.
     * @dev This function determines how a specified amount of assets should be distributed among the sub-vaults
     *      based on the deposit strategy.
     * @param vault The address of the vault for which deposit allocations are being calculated.
     * @param assets The total amount of assets to be deposited.
     * @return subvaultsData An array of `DepositData` structures containing the allocation details for each sub-vault.
     */
    function calculateDepositAmounts(address vault, uint256 assets)
        external
        view
        returns (DepositData[] memory subvaultsData);
}
