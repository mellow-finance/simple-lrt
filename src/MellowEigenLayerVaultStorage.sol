// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/vaults/IMellowEigenLayerVaultStorage.sol";

abstract contract MellowEigenLayerVaultStorage is IMellowEigenLayerVaultStorage, Initializable {
    using EnumerableSet for EnumerableSet.UintSet;

    /// @notice The first slot of the storage.
    bytes32 private immutable _storageSlot;

    constructor(bytes32 name_, uint256 version_) {
        _storageSlot = keccak256(
            abi.encode(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            "mellow.simple-lrt.storage.MellowEigenLayerVaultStorage",
                            name_,
                            version_
                        )
                    )
                ) - 1
            )
        ) & ~bytes32(uint256(0xff));
    }

    function __initializeMellowEigenLayerVaultStorage(
        IDelegationManager delegationManager_,
        IStrategyManager strategyManager_,
        IRewardsCoordinator rewardsCoordinator_,
        IStrategy strategy_,
        address operator_,
        uint256 maxWithdrawalRequests_,
        address withdrawalQueue_
    ) internal onlyInitializing {
        _setDelegationManager(delegationManager_);
        _setStrategyManager(strategyManager_);
        _setRewardsCoordinator(rewardsCoordinator_);
        _setStrategy(strategy_);
        _setStrategyOperator(operator_);
        _setMaxWithdrawalRequests(maxWithdrawalRequests_);
        _setWithdrawalQueue(IEigenLayerWithdrawalQueue(withdrawalQueue_));
    }

    function withdrawalQueue() public view returns (IEigenLayerWithdrawalQueue) {
        return _eigenLayerStorage().withdrawalQueue;
    }

    function delegationManager() public view returns (IDelegationManager) {
        return _eigenLayerStorage().delegationManager;
    }

    function strategyManager() public view returns (IStrategyManager) {
        return _eigenLayerStorage().strategyManager;
    }

    function strategy() public view returns (IStrategy) {
        return _eigenLayerStorage().strategy;
    }

    function strategyOperator() public view returns (address) {
        return _eigenLayerStorage().operator;
    }

    function rewardsCoordinator() public view returns (IRewardsCoordinator) {
        return _eigenLayerStorage().rewardsCoordinator;
    }

    function maxWithdrawalRequests() public view returns (uint256) {
        return _eigenLayerStorage().maxWithdrawalRequests;
    }

    function eigenLayerFarmIds() public view returns (uint256[] memory) {
        return _eigenLayerStorage().farmIds.values();
    }

    function eigenLayerFarmCount() public view returns (uint256) {
        return _eigenLayerStorage().farmIds.length();
    }

    function eigenLayerFarmIdAt(uint256 index) public view returns (uint256) {
        return _eigenLayerStorage().farmIds.at(index);
    }

    function eigenLayerContains(uint256 farmId) public view returns (bool) {
        return _eigenLayerStorage().farmIds.contains(farmId);
    }

    function eigenLayerFarm(uint256 farmId) public view returns (FarmData memory) {
        return _eigenLayerStorage().farms[farmId];
    }

    function _setDelegationManager(IDelegationManager _delegationManager) internal {
        EigenLayerStorage storage s = _eigenLayerStorage();
        s.delegationManager = _delegationManager;
        // emit DelegationManagerSet(address(_delegationManager), block.timestamp);
    }

    function _setRewardsCoordinator(IRewardsCoordinator _rewardsCoordinator) internal {
        EigenLayerStorage storage s = _eigenLayerStorage();
        s.rewardsCoordinator = _rewardsCoordinator;
        // emit RewardsCoordinatorSet(address(_rewardsCoordinator), block.timestamp);
    }

    function _setWithdrawalQueue(IEigenLayerWithdrawalQueue withdrawalQueue_) internal {
        EigenLayerStorage storage s = _eigenLayerStorage();
        s.withdrawalQueue = withdrawalQueue_;
        // emit WithdrawalQueueSet(withdrawalQueue_, block.timestamp);
    }

    function _setStrategyManager(IStrategyManager _strategyManager) internal {
        EigenLayerStorage storage s = _eigenLayerStorage();
        s.strategyManager = _strategyManager;
        // emit StrategyManagerSet(address(_strategyManager), block.timestamp);
    }

    function _setStrategy(IStrategy _strategy) internal {
        EigenLayerStorage storage s = _eigenLayerStorage();
        s.strategy = _strategy;
        // emit StrategySet(address(_strategy), block.timestamp);
    }

    function _setStrategyOperator(address _operator) internal {
        EigenLayerStorage storage s = _eigenLayerStorage();
        s.operator = _operator;
        // emit StrategyOperatorSet(address(_operator), block.timestamp);
    }

    function _setMaxWithdrawalRequests(uint256 maxWithdrawalRequests_) internal {
        EigenLayerStorage storage s = _eigenLayerStorage();
        s.maxWithdrawalRequests = maxWithdrawalRequests_;
        // emit MaxWithdrawalPerClaimSet(maxWithdrawalsPerClaim_, block.timestamp);
    }

    function _setFarm(uint256 farmId, FarmData memory farmData) internal {
        EigenLayerStorage storage s = _eigenLayerStorage();
        s.farms[farmId] = farmData;
        if (farmData.rewardToken != address(0)) {
            s.farmIds.add(farmId);
        } else {
            s.farmIds.remove(farmId);
        }
        // emit FarmSet(farmId, farmData, block.timestamp);
    }

    function _eigenLayerStorage() private view returns (EigenLayerStorage storage $) {
        bytes32 slot = _storageSlot;
        assembly {
            $.slot := slot
        }
    }
}
