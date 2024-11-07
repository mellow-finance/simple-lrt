// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ERC4626Vault} from "./ERC4626Vault.sol";
import {MetaVaultStorage} from "./MetaVaultStorage.sol";
import {VaultControlStorage} from "./VaultControlStorage.sol";

import "./MellowEigenLayerVault.sol";
import "./MellowSymbioticVault.sol";
import "./interfaces/vaults/IMetaVault.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract MultiVaultStorage is Initializable {
    enum SubvaultType {
        SYMBIOTIC,
        EIGEN_LAYER,
        ERC4626
    }

    struct Subvault {
        SubvaultType subvaultType;
        address vault;
        address withdrawalQueue;
    }

    struct MultiStorage {
        address depositStrategy;
        address withdrawalStrategy;
        address rebalanceStrategy;
        address symbioticDefaultCollateral;
        address eigenLayerStrategyManager;
        address eigenLayerDelegationManager;
        address eigenLayerRewardsCoordinator;
        Subvault[] subvaults;
        mapping(address subvault => uint256 index) indexOfSubvault;
    }

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
        address eigenLayerDelegationManager_,
        address eigenLayerRewardsCoordinator_
    ) internal onlyInitializing {
        _setDepositStrategy(depositStrategy_);
        _setWithdrawalStrategy(withdrawalStrategy_);
        _setRebalanceStrategy(rebalanceStrategy_);
        _setSymbioticDefaultCollateral(symbioticDefaultCollateral_);
        _setEigenLayerStrategyManager(eigenLayerStrategyManager_);
        _setEigenLayerDelegationManager(eigenLayerDelegationManager_);
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

    function symbioticDefaultCollateral() public view returns (address) {
        return _multiStorage().symbioticDefaultCollateral;
    }

    function eigenLayerStrategyManager() public view returns (address) {
        return _multiStorage().eigenLayerStrategyManager;
    }

    function eigenLayerDelegationManager() public view returns (address) {
        return _multiStorage().eigenLayerDelegationManager;
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

    function _setDepositStrategy(address newDepositStrategy) internal {
        _multiStorage().depositStrategy = newDepositStrategy;
    }

    function _setWithdrawalStrategy(address newWithdrawalStrategy) internal {
        _multiStorage().withdrawalStrategy = newWithdrawalStrategy;
    }

    function _setRebalanceStrategy(address newRebalanceStrategy) internal {
        _multiStorage().rebalanceStrategy = newRebalanceStrategy;
    }

    function _setSymbioticDefaultCollateral(address newSymbioticDefaultCollateral) internal {
        _multiStorage().symbioticDefaultCollateral = newSymbioticDefaultCollateral;
    }

    function _setEigenLayerStrategyManager(address newEigenLayerStrategyManager) internal {
        _multiStorage().eigenLayerStrategyManager = newEigenLayerStrategyManager;
    }

    function _setEigenLayerDelegationManager(address newEigenLayerDelegationManager) internal {
        _multiStorage().eigenLayerDelegationManager = newEigenLayerDelegationManager;
    }

    function _setEigenLayerRewardsCoordinator(address newEigenLayerRewardsCoordinator) internal {
        _multiStorage().eigenLayerRewardsCoordinator = newEigenLayerRewardsCoordinator;
    }

    function _addSubvault(address vault, address withdrawalQueue, SubvaultType subvaultType)
        internal
    {
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
}
