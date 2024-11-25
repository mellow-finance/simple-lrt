// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./interfaces/vaults/IMultiVaultStorage.sol";

contract MultiVaultStorage is IMultiVaultStorage, Initializable {
    using EnumerableSet for EnumerableSet.UintSet;

    bytes32 private immutable storageSlotRef;

    constructor(bytes32 name_, uint256 version_) {
        storageSlotRef = keccak256(
            abi.encode(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            "mellow.simple-lrt.storage.MultiVaultStorage", name_, version_
                        )
                    )
                ) - 1
            )
        ) & ~bytes32(uint256(0xff));
    }

    function __initializeMultiVaultStorage(
        address depositStrategy_,
        address withdrawalStrategy_,
        address rebalanceStrategy_,
        address symbioticDefaultCollateral_,
        address eigenLayerStrategyManager_,
        address eigenLayerRewardsCoordinator_
    ) internal onlyInitializing {
        _setDepositStrategy(depositStrategy_);
        _setWithdrawalStrategy(withdrawalStrategy_);
        _setRebalanceStrategy(rebalanceStrategy_);
        _setSymbioticDefaultCollateral(symbioticDefaultCollateral_);
        _setEigenLayerStrategyManager(eigenLayerStrategyManager_);
        _setEigenLayerRewardsCoordinator(eigenLayerRewardsCoordinator_);
    }

    function _multiStorage() private view returns (MultiStorage storage $) {
        bytes32 slot = storageSlotRef;
        assembly {
            $.slot := slot
        }
    }

    function subvaultsCount() public view returns (uint256) {
        return _multiStorage().subvaults.length;
    }

    function subvaultAt(uint256 index) public view returns (Subvault memory) {
        return _multiStorage().subvaults[index];
    }

    function indexOfSubvault(address subvault) public view returns (uint256) {
        return _multiStorage().indexOfSubvault[subvault];
    }

    function symbioticDefaultCollateral() public view returns (IDefaultCollateral) {
        return IDefaultCollateral(_multiStorage().symbioticDefaultCollateral);
    }

    function eigenLayerStrategyManager() public view returns (address) {
        return _multiStorage().eigenLayerStrategyManager;
    }

    function eigenLayerDelegationManager() public view returns (IDelegationManager) {
        return IStrategyManager(_multiStorage().eigenLayerStrategyManager).delegation();
    }

    function eigenLayerRewardsCoordinator() public view returns (address) {
        return _multiStorage().eigenLayerRewardsCoordinator;
    }

    function depositStrategy() public view returns (address) {
        return _multiStorage().depositStrategy;
    }

    function withdrawalStrategy() public view returns (address) {
        return _multiStorage().withdrawalStrategy;
    }

    function rebalanceStrategy() public view returns (address) {
        return _multiStorage().rebalanceStrategy;
    }

    function rewardData(uint256 farmId) public view returns (RewardData memory) {
        return _multiStorage().rewardData[farmId];
    }

    function farmIds() public view returns (uint256[] memory) {
        return _multiStorage().farmIds.values();
    }

    function farmCount() public view returns (uint256) {
        return _multiStorage().farmIds.length();
    }

    function farmIdAt(uint256 index) public view returns (uint256) {
        return _multiStorage().farmIds.at(index);
    }

    function farmIdsContains(uint256 farmId) public view returns (bool) {
        return _multiStorage().farmIds.contains(farmId);
    }

    function _setDepositStrategy(address newDepositStrategy) internal {
        if (newDepositStrategy == address(0)) {
            revert("MultiVaultStorage: deposit strategy cannot be zero address");
        }
        _multiStorage().depositStrategy = newDepositStrategy;
    }

    function _setWithdrawalStrategy(address newWithdrawalStrategy) internal {
        if (newWithdrawalStrategy == address(0)) {
            revert("MultiVaultStorage: withdrawal strategy cannot be zero address");
        }
        _multiStorage().withdrawalStrategy = newWithdrawalStrategy;
    }

    function _setRebalanceStrategy(address newRebalanceStrategy) internal {
        if (newRebalanceStrategy == address(0)) {
            revert("MultiVaultStorage: rebalance strategy cannot be zero address");
        }
        _multiStorage().rebalanceStrategy = newRebalanceStrategy;
    }

    function _setSymbioticDefaultCollateral(address newSymbioticDefaultCollateral) internal {
        _multiStorage().symbioticDefaultCollateral = newSymbioticDefaultCollateral;
    }

    function _setEigenLayerStrategyManager(address newEigenLayerStrategyManager) internal {
        _multiStorage().eigenLayerStrategyManager = newEigenLayerStrategyManager;
    }

    function _setEigenLayerRewardsCoordinator(address newEigenLayerRewardsCoordinator) internal {
        _multiStorage().eigenLayerRewardsCoordinator = newEigenLayerRewardsCoordinator;
    }

    function _addSubvault(address vault, address withdrawalQueue, SubvaultType subvaultType)
        internal
    {
        if (subvaultType > type(SubvaultType).max) {
            revert("MultiVaultStorage: invalid subvault type");
        }
        MultiStorage storage $ = _multiStorage();
        require($.indexOfSubvault[vault] == 0, "MultiVaultStorage: subvault already exists");
        $.subvaults.push(Subvault(subvaultType, vault, withdrawalQueue));
        $.indexOfSubvault[vault] = subvaultsCount();
    }

    function _removeSubvault(address subvault) internal {
        MultiStorage storage $ = _multiStorage();
        uint256 index = $.indexOfSubvault[subvault];

        require(index == 0, "MultiVaultStorage: subvault not found");

        index--;
        uint256 last = subvaultsCount() - 1;
        if (index < last) {
            Subvault memory lastSubvault = $.subvaults[last];
            $.subvaults[index] = lastSubvault;
            $.indexOfSubvault[lastSubvault.vault] = index + 1;
        }

        $.subvaults.pop();
        delete $.indexOfSubvault[subvault];
    }

    function _setRewardData(uint256 farmId, RewardData memory data) internal {
        MultiStorage storage $ = _multiStorage();
        if (data.token == address(0)) {
            if ($.farmIds.remove(farmId)) {
                delete $.rewardData[farmId];
            }
        } else {
            $.rewardData[farmId] = data;
            $.farmIds.add(farmId);
        }
    }
}
