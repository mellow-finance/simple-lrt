// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/**
 * @title IProtocolAdapter
 * @notice Interface for protocol adapters that manage interactions with specific vaults and strategies.
 * @dev Provides methods for deposits, withdrawals, rewards management, and validation of sub-vault operations.
 */
interface IProtocolAdapter {
    /**
     * @notice Returns the address of the primary vault associated with this adapter.
     * returns the address of the vault.
     */
    function vault() external view returns (address);

    /**
     * @notice Retrieves the maximum deposit limit for a given sub-vault.
     * @param subvault The address of the sub-vault.
     * returns the maximum deposit amount allowed for the sub-vault.
     */
    function maxDeposit(address subvault) external view returns (uint256);

    /**
     * @notice Returns the amount of assets staked in the specified sub-vault.
     * @param subvault The address of the sub-vault.
     * returns the amount of staked assets in the sub-vault.
     */
    function stakedAt(address subvault) external view returns (uint256);

    /**
     * @notice Returns the address of the asset managed by the specified sub-vault.
     * @param subvault The address of the sub-vault.
     * returns the asset address associated with the sub-vault.
     */
    function assetOf(address subvault) external view returns (address);

    /**
     * @notice Validates the reward data for a given farm or operation.
     * @dev Ensures that the provided reward data is correctly formatted and meets the protocol requirements.
     *      Reverts if the data is invalid.
     * @param data Encoded reward data to be validated.
     */
    function validateRewardData(bytes calldata data) external view;

    /**
     * @notice Pushes reward data to the specified farm for processing.
     * @dev Allows reward distribution to be managed through the specified farm.
     * @param rewardToken The token being used as the reward.
     * @param farmData Encoded data about the farm to which rewards are being pushed.
     * @param rewardData Encoded data specifying the reward details.
     */
    function pushRewards(address rewardToken, bytes calldata farmData, bytes memory rewardData)
        external;

    /**
     * @notice Withdraws assets from the specified sub-vault to a receiver via a withdrawal queue.
     * @param subvault The address of the sub-vault from which assets are withdrawn.
     * @param withdrawalQueue The address of the withdrawal queue handling the withdrawal.
     * @param receiver The address receiving the withdrawn assets.
     * @param request The amount of assets requested for withdrawal.
     * @param owner The owner of the assets being withdrawn.
     */
    function withdraw(
        address subvault,
        address withdrawalQueue,
        address receiver,
        uint256 request,
        address owner
    ) external;

    /**
     * @notice Deposits a specified amount of assets into the given sub-vault.
     * @param subvault The address of the sub-vault into which assets are deposited.
     * @param assets The amount of assets to deposit.
     */
    function deposit(address subvault, uint256 assets) external;

    /**
     * @notice Handles the setup or registration of the withdrawal queue for the specified sub-vault.
     * @param subvault The address of the sub-vault.
     * @return withdrawalQueue The address of the associated withdrawal queue.
     */
    function handleVault(address subvault) external returns (address withdrawalQueue);

    /**
     * @notice Checks whether withdrawals are currently paused for a specific sub-vault and account.
     * @param subvault The address of the sub-vault.
     * @param account The address of the account attempting to withdraw.
     * @return True if withdrawals are paused for the specified sub-vault and account, false otherwise.
     */
    function areWithdrawalsPaused(address subvault, address account) external view returns (bool);
}
