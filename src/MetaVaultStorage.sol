// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {
    EnumerableSet,
    IMetaVaultStorage,
    Initializable
} from "./interfaces/vaults/IMetaVaultStorage.sol";

abstract contract MetaVaultStorage is IMetaVaultStorage, Initializable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc IMetaVaultStorage
    uint256 public constant MAX_SUBVAULTS = 16;
    bytes32 private immutable storageSlotRef;

    constructor(bytes32 name_, uint256 version_) {
        storageSlotRef = keccak256(
            abi.encode(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            "mellow.simple-lrt.storage.MetaVaultStorage", name_, version_
                        )
                    )
                ) - 1
            )
        ) & ~bytes32(uint256(0xff));
    }

    // ------------------------------- EXTERNAL FUNCTIONS -------------------------------

    /// @inheritdoc IMetaVaultStorage
    function subvaults() public view returns (address[] memory) {
        return _metaStorage().subvaults.values();
    }

    /// @inheritdoc IMetaVaultStorage
    function subvaultAt(uint256 index) public view returns (address) {
        MetaStorage storage $ = _metaStorage();
        if ($.subvaults.length() <= index) {
            revert("MetaVaultStorage: subvault index out of bounds");
        }
        return $.subvaults.at(index);
    }

    /// @inheritdoc IMetaVaultStorage
    function isQueuedVault(address subvault) public view returns (bool) {
        return _metaStorage().isQueuedVault[subvault];
    }

    /// @inheritdoc IMetaVaultStorage
    function hasSubvault(address subvault) public view returns (bool) {
        return _metaStorage().subvaults.contains(subvault);
    }

    /// @inheritdoc IMetaVaultStorage
    function subvaultsCount() public view returns (uint256) {
        return _metaStorage().subvaults.length();
    }

    /// @inheritdoc IMetaVaultStorage
    function depositStrategy() public view returns (address) {
        return _metaStorage().depositStrategy;
    }

    /// @inheritdoc IMetaVaultStorage
    function withdrawalStrategy() public view returns (address) {
        return _metaStorage().withdrawalStrategy;
    }

    /// @inheritdoc IMetaVaultStorage
    function rebalanceStrategy() public view returns (address) {
        return _metaStorage().rebalanceStrategy;
    }

    /// @inheritdoc IMetaVaultStorage
    function subvaultsHash() public view returns (bytes32) {
        return _metaStorage().subvaultsHash;
    }

    // ------------------------------- INTERNAL FUNCTIONS -------------------------------

    function __initializeMetaVaultStorage(
        address depositStrategy_,
        address withdrawalStrategy_,
        address rebalanceStrategy_,
        address idleVault_
    ) internal onlyInitializing {
        _setDepositStrategy(depositStrategy_);
        _setWithdrawalStrategy(withdrawalStrategy_);
        _setRebalanceStrategy(rebalanceStrategy_);
        _addSubvault(idleVault_, false);
        emit MetaVaultStorageInitialized(tx.origin, idleVault_);
    }

    function _setDepositStrategy(address newDepositStrategy) internal {
        if (newDepositStrategy == address(0)) {
            revert("MetaVaultStorage: deposit strategy is zero address");
        }
        _metaStorage().depositStrategy = newDepositStrategy;
        emit DepositStrategySet(newDepositStrategy);
    }

    function _setWithdrawalStrategy(address newWithdrawalStrategy) internal {
        if (newWithdrawalStrategy == address(0)) {
            revert("MetaVaultStorage: withdrawal strategy is zero address");
        }
        _metaStorage().withdrawalStrategy = newWithdrawalStrategy;
        emit WithdrawalStrategySet(newWithdrawalStrategy);
    }

    function _setRebalanceStrategy(address newRebalanceStrategy) internal {
        if (newRebalanceStrategy == address(0)) {
            revert("MetaVaultStorage: rebalance strategy is zero address");
        }
        _metaStorage().rebalanceStrategy = newRebalanceStrategy;
        emit RebalanceStrategySet(newRebalanceStrategy);
    }

    function _addSubvault(address subvault, bool isQueuedVault) internal {
        MetaStorage storage $ = _metaStorage();
        if ($.subvaults.length() + 1 > MAX_SUBVAULTS) {
            revert("MetaVaultStorage: subvaults limit reached");
        }
        if (!$.subvaults.add(subvault)) {
            revert("MetaVaultStorage: subvault already exists");
        }
        $.subvaultsHash = keccak256(abi.encodePacked($.subvaults.values()));
        $.isQueuedVault[subvault] = isQueuedVault;
        emit SubvaultAdded(subvault, isQueuedVault);
    }

    function _removeSubvault(address subvault) internal {
        MetaStorage storage $ = _metaStorage();
        if ($.subvaults.at(0) == subvault) {
            revert("MetaVaultStorage: cannot remove idle vault");
        }
        if (!$.subvaults.remove(subvault)) {
            revert("MetaVaultStorage: subvault not found");
        }
        $.subvaultsHash = keccak256(abi.encodePacked($.subvaults.values()));
        delete $.isQueuedVault[subvault];
        emit SubvaultRemoved(subvault);
    }

    function _metaStorage() private view returns (MetaStorage storage $) {
        bytes32 slot = storageSlotRef;
        assembly {
            $.slot := slot
        }
    }
}
