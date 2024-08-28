// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

/**
 * @title IWithdrawalQueue
 * @notice Handle withdrawal process from underlying vault.
 */
interface IWithdrawalQueue {
    /**
     * @notice Returns claimable collateral by the Vault at current and the next epochs.
     */
    function pendingAssets() external view returns (uint256);

    /**
     * @notice Returns claimable and pending (at current and the next epochs) collateral amount for the given `account`.
     * @param account Address of the account.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @notice Returns pending (at current and the next epochs) collateral amount for the given `account`.
     * @param account Address of the account.
     */
    function pendingAssetsOf(address account) external view returns (uint256);

    /**
     * @notice Returns claimable collateral amount for the given `account`.
     * @param account Address of the account.
     */
    function claimableAssetsOf(address account) external view returns (uint256);

    /**
     * @notice Claims `amount` of collateral from the Simbiotic Vault at current and previous epochs.
     * @param account Address of the account.
     * @param amount Amount of collateral.
     * 
     * @custom:requirements
     * - `msg.sender` MUST be the Vault.
     * - `amount` MUST be grather than zero.
     * 
     * @custom:effects
     * - Emits WithdrawalRequested event.
     */
    function request(address account, uint256 amount) external;

    /**
     * @notice Claims `amount` of collateral from the Simbiotic Vault at the given epoch.
     * @param epoch Number of epoch to claim at.
     * 
     * @custom:requirements
     * - epoch MUST be claimable.
     * - Checks whether there is claimable withdrawals.
     * 
     * @custom:effects
     * - Emits EpochClaimed event.
     */
    function pull(uint256 epoch) external;

    /**
     * @notice Claims collateral in favor of `recipient`.
     * @dev Claims and transfers min(claimable amount, maxAmount) to the `recipient`.
     * @param account Address of account to claim.
     * @param recipient Address of recipient of collateral.
     * @param maxAmount Max amount of collateral this will be claimed.
     * 
     * @custom:requirements
     * - `msg.sender` MUST be the Vault or `account`.
     * - Claimable amount MUST be grather than zero.
     * - Checks whether there is claimable withdrawals for the given `account`.
     * 
     * @custom:effects
     * - Emits Claimed event.
     */
    function claim(address account, address recipient, uint256 maxAmount)
        external
        returns (uint256 amount);
}
