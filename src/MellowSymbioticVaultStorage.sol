// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/vaults/IMellowSymbioticVaultStorage.sol";

abstract contract MellowSymbioticVaultStorage is IMellowSymbioticVaultStorage, Initializable {
    using EnumerableSet for EnumerableSet.UintSet;

    bytes32 private immutable storageSlotRef;

    constructor(bytes32 name_, uint256 version_) {
        storageSlotRef = keccak256(
            abi.encode(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            "mellow.simple-lrt.storage.MellowSymbioticVaultStorage", name_, version_
                        )
                    )
                ) - 1
            )
        ) & ~bytes32(uint256(0xff));
    }

    function __initializeMellowSymbioticVaultStorage(
        address _symbioticVault,
        address _withdrawalQueue
    ) internal onlyInitializing {
        _setSymbioticVault(ISymbioticVault(_symbioticVault));
        _setWithdrawalQueue(IWithdrawalQueue(_withdrawalQueue));
    }

    /// @inheritdoc IMellowSymbioticVaultStorage
    function symbioticVault() public view returns (ISymbioticVault) {
        return _symbioticStorage().symbioticVault;
    }

    /// @inheritdoc IMellowSymbioticVaultStorage
    function withdrawalQueue() public view returns (IWithdrawalQueue) {
        return _symbioticStorage().withdrawalQueue;
    }

    /// @inheritdoc IMellowSymbioticVaultStorage
    function symbioticFarmIds() public view returns (uint256[] memory) {
        return _symbioticStorage().farmIds.values();
    }

    /// @inheritdoc IMellowSymbioticVaultStorage
    function symbioticFarmCount() public view returns (uint256) {
        return _symbioticStorage().farmIds.length();
    }

    /// @inheritdoc IMellowSymbioticVaultStorage
    function symbioticFarmIdAt(uint256 index) public view returns (uint256) {
        return _symbioticStorage().farmIds.at(index);
    }

    /// @inheritdoc IMellowSymbioticVaultStorage
    function symbioticFarmsContains(uint256 farmId) public view returns (bool) {
        return _symbioticStorage().farmIds.contains(farmId);
    }

    /// @inheritdoc IMellowSymbioticVaultStorage
    function symbioticFarm(uint256 farmId) public view returns (FarmData memory) {
        return _symbioticStorage().farms[farmId];
    }

    function _setSymbioticVault(ISymbioticVault _symbioticVault) internal {
        SymbioticStorage storage s = _symbioticStorage();
        s.symbioticVault = _symbioticVault;
        emit SymbioticVaultSet(address(_symbioticVault), block.timestamp);
    }

    function _setWithdrawalQueue(IWithdrawalQueue _withdrawalQueue) internal {
        SymbioticStorage storage s = _symbioticStorage();
        s.withdrawalQueue = _withdrawalQueue;
        emit WithdrawalQueueSet(address(_withdrawalQueue), block.timestamp);
    }

    function _setFarm(uint256 farmId, FarmData memory farmData) internal {
        SymbioticStorage storage s = _symbioticStorage();
        s.farms[farmId] = farmData;
        if (farmData.rewardToken != address(0)) {
            s.farmIds.add(farmId);
        } else {
            s.farmIds.remove(farmId);
        }
        emit FarmSet(farmId, farmData, block.timestamp);
    }

    function _symbioticStorage() private view returns (SymbioticStorage storage $) {
        bytes32 slot = storageSlotRef;
        assembly {
            $.slot := slot
        }
    }
}
