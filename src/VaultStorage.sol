// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/vaults/IVaultStorage.sol";

abstract contract VaultStorage is IVaultStorage {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public immutable NAME;
    uint256 public immutable VERSION;
    bytes32 public immutable storageSlotRef;

    constructor(bytes32 name_, uint256 version_) {
        NAME = name_;
        VERSION = version_;
        storageSlotRef = keccak256(
            abi.encode(
                uint256(
                    keccak256(
                        abi.encodePacked("mellow.simple-lrt.storage.VaultStorage", name_, version_)
                    )
                ) - 1
            )
        ) & ~bytes32(uint256(0xff)) & ~bytes32(uint256(0xff));
    }

    function __initializeStorage(
        address _symbioticCollateral,
        address _symbioticVault,
        address _withdrawalQueue,
        uint256 _limit,
        bool _paused
    ) internal {
        _setSymbioticCollateral(IDefaultCollateral(_symbioticCollateral));
        _setSymbioticVault(ISymbioticVault(_symbioticVault));
        _setWithdrawalQueue(IWithdrawalQueue(_withdrawalQueue));
        _setLimit(_limit);
        _setDepositPause(_paused);
        _setWithdrawalPause(_paused);
    }

    function symbioticCollateral() public view returns (IDefaultCollateral) {
        return _contractStorage().symbioticCollateral;
    }

    function symbioticVault() public view returns (ISymbioticVault) {
        return _contractStorage().symbioticVault;
    }

    function withdrawalQueue() public view returns (IWithdrawalQueue) {
        return _contractStorage().withdrawalQueue;
    }

    function depositPause() public view returns (bool) {
        return _contractStorage().depositPause;
    }

    function withdrawalPause() public view returns (bool) {
        return _contractStorage().withdrawalPause;
    }

    function limit() public view returns (uint256) {
        return _contractStorage().limit;
    }

    function symbioticRewardTokens() public view returns (address[] memory) {
        return _contractStorage().rewardTokens.values();
    }

    function symbioticFarm(address rewardToken) public view returns (FarmData memory) {
        return _contractStorage().farms[rewardToken];
    }

    function _setLimit(uint256 _limit) internal {
        Storage storage s = _contractStorage();
        s.limit = _limit;
    }

    function _setDepositPause(bool _paused) internal {
        Storage storage s = _contractStorage();
        s.depositPause = _paused;
    }

    function _setWithdrawalPause(bool _paused) internal {
        Storage storage s = _contractStorage();
        s.withdrawalPause = _paused;
    }

    function _setSymbioticCollateral(IDefaultCollateral _symbioticCollateral) internal {
        Storage storage s = _contractStorage();
        s.symbioticCollateral = _symbioticCollateral;
    }

    function _setSymbioticVault(ISymbioticVault _symbioticVault) internal {
        Storage storage s = _contractStorage();
        s.symbioticVault = _symbioticVault;
    }

    function _setWithdrawalQueue(IWithdrawalQueue _withdrawalQueue) internal {
        Storage storage s = _contractStorage();
        s.withdrawalQueue = _withdrawalQueue;
    }

    function _setFarm(address rewardToken, FarmData memory farmData) internal {
        Storage storage s = _contractStorage();
        s.farms[rewardToken] = farmData;
        s.rewardTokens.add(rewardToken);
    }

    function _removeFarm(address rewardToken) internal {
        Storage storage s = _contractStorage();
        delete s.farms[rewardToken];
        s.rewardTokens.remove(rewardToken);
    }

    function _contractStorage() private view returns (Storage storage $) {
        bytes32 slot = storageSlotRef;
        assembly {
            $.slot := slot
        }
    }
}
