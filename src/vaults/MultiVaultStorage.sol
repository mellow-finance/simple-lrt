// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/vaults/IMultiVaultStorage.sol";

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

    function defaultCollateral() public view returns (IDefaultCollateral) {
        return IDefaultCollateral(_multiStorage().defaultCollateral);
    }

    function depositStrategy() public view returns (IDepositStrategy) {
        return IDepositStrategy(_multiStorage().depositStrategy);
    }

    function withdrawalStrategy() public view returns (IWithdrawalStrategy) {
        return IWithdrawalStrategy(_multiStorage().withdrawalStrategy);
    }

    function rebalanceStrategy() public view returns (IRebalanceStrategy) {
        return IRebalanceStrategy(_multiStorage().rebalanceStrategy);
    }

    function symbioticAdapter() public view returns (IProtocolAdapter) {
        return IProtocolAdapter(_multiStorage().symbioticAdapter);
    }

    function eigenLayerAdapter() public view returns (IProtocolAdapter) {
        return IProtocolAdapter(_multiStorage().eigenLayerAdapter);
    }

    function erc4626Adapter() public view returns (IProtocolAdapter) {
        return IProtocolAdapter(_multiStorage().erc4626Adapter);
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

    function _setSymbioticAdapter(address symbioticAdapter_) internal {
        _multiStorage().symbioticAdapter = symbioticAdapter_;
    }

    function _setEigenLayerAdapter(address eigenLayerAdapter_) internal {
        _multiStorage().eigenLayerAdapter = eigenLayerAdapter_;
    }

    function _setERC4626Adapter(address erc4626Adapter_) internal {
        _multiStorage().erc4626Adapter = erc4626Adapter_;
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
        _multiStorage().rebalanceStrategy = newRebalanceStrategy;
    }

    function _setDefaultCollateral(address defaultCollateral_) internal {
        _multiStorage().defaultCollateral = defaultCollateral_;
    }

    function _addSubvault(address vault, address withdrawalQueue, Protocol protocol) internal {
        if (protocol > type(Protocol).max) {
            revert("MultiVaultStorage: invalid subvault type");
        }
        MultiStorage storage $ = _multiStorage();
        require($.indexOfSubvault[vault] == 0, "MultiVaultStorage: subvault already exists");
        $.subvaults.push(Subvault(protocol, vault, withdrawalQueue));
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
