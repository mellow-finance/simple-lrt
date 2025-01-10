// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/vaults/IMultiVaultStorage.sol";

/**
 * @title MultiVaultStorage
 * @notice Provides storage and utility functions for managing strategies, adapters, and subvaults in a multi-vault setup.
 * @dev Implements `IMultiVaultStorage` and includes initialization and internal management logic.
 */
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

    function _multiStorage() private view returns (MultiStorage storage $) {
        bytes32 slot = storageSlotRef;
        assembly {
            $.slot := slot
        }
    }

    /// ------------------------------- EXTERNAL VIEW FUNCTIONS -------------------------------

    /// @inheritdoc IMultiVaultStorage
    function subvaultsCount() public view returns (uint256) {
        return _multiStorage().subvaults.length;
    }

    /// @inheritdoc IMultiVaultStorage
    function subvaultAt(uint256 index) public view returns (Subvault memory) {
        return _multiStorage().subvaults[index];
    }

    /// @inheritdoc IMultiVaultStorage
    function indexOfSubvault(address subvault) public view returns (uint256) {
        return _multiStorage().indexOfSubvault[subvault];
    }

    /// @inheritdoc IMultiVaultStorage
    function defaultCollateral() public view returns (IDefaultCollateral) {
        return IDefaultCollateral(_multiStorage().defaultCollateral);
    }

    /// @inheritdoc IMultiVaultStorage
    function depositStrategy() public view returns (IDepositStrategy) {
        return IDepositStrategy(_multiStorage().depositStrategy);
    }

    /// @inheritdoc IMultiVaultStorage
    function withdrawalStrategy() public view returns (IWithdrawalStrategy) {
        return IWithdrawalStrategy(_multiStorage().withdrawalStrategy);
    }

    /// @inheritdoc IMultiVaultStorage
    function rebalanceStrategy() public view returns (IRebalanceStrategy) {
        return IRebalanceStrategy(_multiStorage().rebalanceStrategy);
    }

    /// @inheritdoc IMultiVaultStorage
    function symbioticAdapter() public view returns (IProtocolAdapter) {
        return IProtocolAdapter(_multiStorage().symbioticAdapter);
    }

    /// @inheritdoc IMultiVaultStorage
    function eigenLayerAdapter() public view returns (IProtocolAdapter) {
        return IProtocolAdapter(_multiStorage().eigenLayerAdapter);
    }

    /// @inheritdoc IMultiVaultStorage
    function erc4626Adapter() public view returns (IProtocolAdapter) {
        return IProtocolAdapter(_multiStorage().erc4626Adapter);
    }

    /// @inheritdoc IMultiVaultStorage
    function rewardData(uint256 farmId) public view returns (RewardData memory) {
        return _multiStorage().rewardData[farmId];
    }

    /// @inheritdoc IMultiVaultStorage
    function farmIds() public view returns (uint256[] memory) {
        return _multiStorage().farmIds.values();
    }

    /// @inheritdoc IMultiVaultStorage
    function farmCount() public view returns (uint256) {
        return _multiStorage().farmIds.length();
    }

    /// @inheritdoc IMultiVaultStorage
    function farmIdAt(uint256 index) public view returns (uint256) {
        return _multiStorage().farmIds.at(index);
    }

    /// @inheritdoc IMultiVaultStorage
    function farmIdsContains(uint256 farmId) public view returns (bool) {
        return _multiStorage().farmIds.contains(farmId);
    }

    /// @inheritdoc IMultiVaultStorage
    function adapterOf(Protocol protocol) public view returns (IProtocolAdapter adapter) {
        if (protocol == Protocol.SYMBIOTIC) {
            adapter = symbioticAdapter();
        } else if (protocol == Protocol.EIGEN_LAYER) {
            adapter = eigenLayerAdapter();
        } else if (protocol == Protocol.ERC4626) {
            adapter = erc4626Adapter();
        }
        require(address(adapter) != address(0), "MultiVault: unsupported protocol");
    }

    /// ------------------------------- INTERNAL MUTATIVE FUNCTIONS -------------------------------

    /**
     * @notice Initializes the multi-vault storage with the provided strategies and adapters.
     * @dev This function is protected by the `onlyInitializing` modifier and is intended to be called during contract initialization.
     * @param depositStrategy_ Address of the deposit strategy.
     * @param withdrawalStrategy_ Address of the withdrawal strategy.
     * @param rebalanceStrategy_ Address of the rebalance strategy.
     * @param defaultCollateral_ Address of the default collateral.
     * @param symbioticAdapter_ Address of the symbiotic adapter.
     * @param eigenLayerAdapter_ Address of the EigenLayer adapter.
     * @param erc4626Adapter_ Address of the ERC4626 adapter.
     */
    function __initializeMultiVaultStorage(
        address depositStrategy_,
        address withdrawalStrategy_,
        address rebalanceStrategy_,
        address defaultCollateral_,
        address symbioticAdapter_,
        address eigenLayerAdapter_,
        address erc4626Adapter_
    ) internal onlyInitializing {
        _setDepositStrategy(depositStrategy_);
        _setWithdrawalStrategy(withdrawalStrategy_);
        _setRebalanceStrategy(rebalanceStrategy_);
        _setDefaultCollateral(defaultCollateral_);
        _setSymbioticAdapter(symbioticAdapter_);
        _setEigenLayerAdapter(eigenLayerAdapter_);
        _setERC4626Adapter(erc4626Adapter_);
    }

    /**
     * @notice Sets the symbiotic adapter address.
     * @param symbioticAdapter_ Address of the new symbiotic adapter.
     */
    function _setSymbioticAdapter(address symbioticAdapter_) internal {
        _multiStorage().symbioticAdapter = symbioticAdapter_;
        emit SymbioticAdapterSet(symbioticAdapter_);
    }

    /**
     * @notice Sets the EigenLayer adapter address.
     * @param eigenLayerAdapter_ Address of the new EigenLayer adapter.
     */
    function _setEigenLayerAdapter(address eigenLayerAdapter_) internal {
        _multiStorage().eigenLayerAdapter = eigenLayerAdapter_;
        emit EigenLayerAdapterSet(eigenLayerAdapter_);
    }

    /**
     * @notice Sets the ERC4626 adapter address.
     * @param erc4626Adapter_ Address of the new ERC4626 adapter.
     */
    function _setERC4626Adapter(address erc4626Adapter_) internal {
        _multiStorage().erc4626Adapter = erc4626Adapter_;
        emit ERC4626AdapterSet(erc4626Adapter_);
    }

    /**
     * @notice Sets the deposit strategy address.
     * @param newDepositStrategy Address of the new deposit strategy.
     */
    function _setDepositStrategy(address newDepositStrategy) internal {
        _multiStorage().depositStrategy = newDepositStrategy;
        emit DepositStrategySet(newDepositStrategy);
    }

    /**
     * @notice Sets the withdrawal strategy address.
     * @param newWithdrawalStrategy Address of the new withdrawal strategy.
     */
    function _setWithdrawalStrategy(address newWithdrawalStrategy) internal {
        _multiStorage().withdrawalStrategy = newWithdrawalStrategy;
        emit WithdrawalStrategySet(newWithdrawalStrategy);
    }

    /**
     * @notice Sets the rebalance strategy address.
     * @param newRebalanceStrategy Address of the new rebalance strategy.
     */
    function _setRebalanceStrategy(address newRebalanceStrategy) internal {
        _multiStorage().rebalanceStrategy = newRebalanceStrategy;
        emit RebalanceStrategySet(newRebalanceStrategy);
    }

    /**
     * @notice Sets the default collateral address.
     * @param defaultCollateral_ Address of the new default collateral.
     */
    function _setDefaultCollateral(address defaultCollateral_) internal {
        _multiStorage().defaultCollateral = defaultCollateral_;
        emit DefaultCollateralSet(defaultCollateral_);
    }

    /**
     * @notice Adds a new subvault to the storage.
     * @param vault Address of the subvault.
     * @param withdrawalQueue Address of the withdrawal queue associated with the subvault.
     * @param protocol Protocol type of the subvault.
     */
    function _addSubvault(address vault, address withdrawalQueue, Protocol protocol) internal {
        MultiStorage storage $ = _multiStorage();
        require($.indexOfSubvault[vault] == 0, "MultiVaultStorage: subvault already exists");
        $.subvaults.push(Subvault(protocol, vault, withdrawalQueue));
        uint256 index = $.subvaults.length;
        $.indexOfSubvault[vault] = index;
        emit SubvaultAdded(vault, withdrawalQueue, protocol, index - 1);
    }

    /**
     * @notice Removes a subvault from the storage.
     * @param vault Address of the subvault to remove.
     */
    function _removeSubvault(address vault) internal {
        MultiStorage storage $ = _multiStorage();
        uint256 index = $.indexOfSubvault[vault];
        require(index != 0, "MultiVaultStorage: subvault not found");
        index--;
        uint256 last = $.subvaults.length - 1;
        emit SubvaultRemoved(vault, index);
        if (index < last) {
            Subvault memory lastSubvault = $.subvaults[last];
            $.subvaults[index] = lastSubvault;
            $.indexOfSubvault[lastSubvault.vault] = index + 1;
            emit SubvaultIndexChanged(lastSubvault.vault, last, index);
        }
        $.subvaults.pop();
        delete $.indexOfSubvault[vault];
    }

    /**
     * @notice Sets reward data for a farm.
     * @param farmId ID of the farm.
     * @param data Reward data to set.
     */
    function _setRewardData(uint256 farmId, RewardData memory data) internal {
        MultiStorage storage $ = _multiStorage();
        if (data.token == address(0)) {
            if ($.farmIds.remove(farmId)) {
                delete $.rewardData[farmId];
                emit RewardDataRemoved(farmId);
            }
        } else {
            $.rewardData[farmId] = data;
            $.farmIds.add(farmId);
            emit RewardDataSet(farmId, data);
        }
    }
}
