// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/vaults/IMellowSymbioticVaultStorage.sol";

abstract contract MellowSymbioticVaultStorage is IMellowSymbioticVaultStorage, Initializable {
    using EnumerableSet for EnumerableSet.AddressSet;

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
        ) & ~bytes32(uint256(0xff)) & ~bytes32(uint256(0xff));
    }

    function __initializeMellowSymbioticVaultStorage(
        address _symbioticVault,
        address _symbioticCollateral,
        address _withdrawalQueue
    ) internal onlyInitializing {
        _setSymbioticVault(ISymbioticVault(_symbioticVault));
        _setSymbioticCollateral(IDefaultCollateral(_symbioticCollateral));
        _setWithdrawalQueue(IWithdrawalQueue(_withdrawalQueue));
    }

    function symbioticCollateral() public view returns (IDefaultCollateral) {
        return _symbioticStorage().symbioticCollateral;
    }

    function symbioticVault() public view returns (ISymbioticVault) {
        return _symbioticStorage().symbioticVault;
    }

    function withdrawalQueue() public view returns (IWithdrawalQueue) {
        return _symbioticStorage().withdrawalQueue;
    }

    function symbioticRewardTokens() public view returns (address[] memory) {
        return _symbioticStorage().rewardTokens.values();
    }

    function symbioticFarm(address rewardToken) public view returns (FarmData memory) {
        return _symbioticStorage().farms[rewardToken];
    }

    function _setSymbioticCollateral(IDefaultCollateral _symbioticCollateral) internal {
        SymbioticStorage storage s = _symbioticStorage();
        s.symbioticCollateral = _symbioticCollateral;
        emit SymbioticCollateralSet(address(_symbioticCollateral), block.timestamp);
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

    function _setFarm(address rewardToken, FarmData memory farmData) internal {
        SymbioticStorage storage s = _symbioticStorage();
        s.farms[rewardToken] = farmData;
        if (farmData.symbioticFarm != address(0)) {
            s.rewardTokens.add(rewardToken);
        } else {
            s.rewardTokens.remove(rewardToken);
        }
        emit FarmSet(rewardToken, farmData, block.timestamp);
    }

    function _symbioticStorage() private view returns (SymbioticStorage storage $) {
        bytes32 slot = storageSlotRef;
        assembly {
            $.slot := slot
        }
    }
}
