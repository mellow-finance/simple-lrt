// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./IMultiVaultStorage.sol";

interface IMultiVault is IMultiVaultStorage {
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
        address symbioticDefaultCollateral;
        address eigenLayerStrategyManager;
        address eigenLayerRewardsCoordinator;
    }

    // ------------------------------- EXTERNAL FUNCTIONS -------------------------------

    function initialize(InitParams calldata initParams) external;

    function maxDeposit(uint256 subvaultIndex) external view returns (uint256);

    function maxWithdraw(uint256 subvaultIndex)
        external
        view
        returns (uint256 claimable, uint256 pending, uint256 staked);

    function addSubvault(address vault, address withdrawalQueue, SubvaultType subvaultType)
        external;

    function removeSubvault(address subvault) external;

    function setDepositStrategy(address newDepositStrategy) external;

    function setWithdrawalStrategy(address newWithdrawalStrategy) external;

    function setRebalanceStrategy(address newRebalanceStrategy) external;

    function setSymbioticDefaultCollateral(address newSymbioticDefaultCollateral) external;

    function setEigenLayerStrategyManager(address newEigenLayerStrategyManager) external;

    function setEigenLayerRewardsCoordinator(address newEigenLayerRewardsCoordinator) external;

    function rebalance() external;

    function pushRewards(uint256 farmId, bytes calldata data) external;
}
