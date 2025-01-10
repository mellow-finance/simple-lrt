// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./IMultiVaultStorage.sol";

/**
 * @title IMultiVault
 * @notice Interface for a multi-protocol vault supporting deposits, withdrawals, rebalancing, and rewards.
 * @dev Extends `IMultiVaultStorage` and introduces various initialization, configuration, and operational methods.
 */
interface IMultiVault is IMultiVaultStorage {
    /**
     * @notice Parameters for initializing the multi-vault.
     * @dev Contains configuration for vault settings, strategies, and adapters.
     * @param admin The address of the vault administrator.
     * @param limit The maximum allowable deposit limit.
     * @param depositPause A boolean to pause deposits.
     * @param withdrawalPause A boolean to pause withdrawals.
     * @param depositWhitelist A boolean to enable or disable deposit whitelisting.
     * @param asset The address of the underlying asset managed by the vault.
     * @param name The name of the vault token.
     * @param symbol The symbol of the vault token.
     * @param depositStrategy The address of the deposit strategy contract.
     * @param withdrawalStrategy The address of the withdrawal strategy contract.
     * @param rebalanceStrategy The address of the rebalance strategy contract.
     * @param defaultCollateral The address of the default collateral contract.
     * @param symbioticAdapter The address of the symbiotic adapter contract.
     * @param eigenLayerAdapter The address of the EigenLayer adapter contract.
     * @param erc4626Adapter The address of the ERC4626 adapter contract.
     */
    struct InitParams {
        address admin;
        uint256 limit;
        bool depositPause;
        bool withdrawalPause;
        bool depositWhitelist;
        address asset;
        string name;
        string symbol;
        address depositStrategy;
        address withdrawalStrategy;
        address rebalanceStrategy;
        address defaultCollateral;
        address symbioticAdapter;
        address eigenLayerAdapter;
        address erc4626Adapter;
    }

    /**
     * @notice Initializes the multi-vault with the provided parameters.
     * @param initParams The initialization parameters.
     */
    function initialize(InitParams calldata initParams) external;

    /**
     * @notice Executes the rebalancing logic for the vault.
     * @dev Rebalances assets across sub-vaults according to the rebalance strategy.
     */
    function rebalance() external;

    /**
     * @notice Adds a new sub-vault to the multi-vault.
     * @param vault The address of the sub-vault.
     * @param protocol The protocol associated with the sub-vault.
     */
    function addSubvault(address vault, Protocol protocol) external;

    /**
     * @notice Removes a sub-vault from the multi-vault.
     * @param subvault The address of the sub-vault to be removed.
     */
    function removeSubvault(address subvault) external;

    /**
     * @notice Updates the deposit strategy for the vault.
     * @param newDepositStrategy The address of the new deposit strategy contract.
     */
    function setDepositStrategy(address newDepositStrategy) external;

    /**
     * @notice Updates the withdrawal strategy for the vault.
     * @param newWithdrawalStrategy The address of the new withdrawal strategy contract.
     */
    function setWithdrawalStrategy(address newWithdrawalStrategy) external;

    /**
     * @notice Updates the rebalance strategy for the vault.
     * @param newRebalanceStrategy The address of the new rebalance strategy contract.
     */
    function setRebalanceStrategy(address newRebalanceStrategy) external;

    /**
     * @notice Sets the reward data for a specific farm.
     * @param farmId The ID of the farm.
     * @param rewardData The reward data to be associated with the farm.
     */
    function setRewardsData(uint256 farmId, RewardData calldata rewardData) external;

    /**
     * @notice Sets the default collateral contract for the vault.
     * @param defaultCollateral_ The address of the new default collateral contract.
     */
    function setDefaultCollateral(address defaultCollateral_) external;

    /**
     * @notice Sets the symbiotic adapter contract for the vault.
     * @param adapter_ The address of the new symbiotic adapter contract.
     */
    function setSymbioticAdapter(address adapter_) external;

    /**
     * @notice Sets the EigenLayer adapter contract for the vault.
     * @param adapter_ The address of the new EigenLayer adapter contract.
     */
    function setEigenLayerAdapter(address adapter_) external;

    /**
     * @notice Sets the ERC4626 adapter contract for the vault.
     * @param adapter_ The address of the new ERC4626 adapter contract.
     */
    function setERC4626Adapter(address adapter_) external;

    /**
     * @notice Pushes rewards to a specific farm.
     * @param farmId The ID of the farm.
     * @param data The encoded reward data.
     */
    function pushRewards(uint256 farmId, bytes calldata data) external;

    /**
     * @notice Emitted when rebalancing is executed.
     * @param data The rebalance data for sub-vaults.
     * @param timestamp The timestamp of the rebalance execution.
     */
    event Rebalance(IRebalanceStrategy.RebalanceData[] data, uint256 timestamp);

    /**
     * @notice Emitted when assets are deposited into the collateral.
     * @param assets The amount of assets deposited.
     */
    event DepositIntoCollateral(uint256 assets);

    /**
     * @notice Emitted when rewards are pushed to a farm.
     * @param farmId The ID of the farm receiving rewards.
     * @param rewardAmount The amount of rewards pushed.
     * @param curatorFee The fee taken by the curator.
     * @param timestamp The timestamp of the reward push.
     */
    event RewardsPushed(
        uint256 indexed farmId,
        uint256 indexed rewardAmount,
        uint256 indexed curatorFee,
        uint256 timestamp
    );
}
