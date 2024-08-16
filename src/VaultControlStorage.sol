// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/vaults/IVaultControlStorage.sol";

abstract contract VaultControlStorage is IVaultControlStorage {
    bytes32 private immutable storageSlotRef;

    constructor(bytes32 name_, uint256 version_) {
        storageSlotRef = keccak256(
            abi.encode(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            "mellow.simple-lrt.storage.VaultControlStorage", name_, version_
                        )
                    )
                ) - 1
            )
        ) & ~bytes32(uint256(0xff)) & ~bytes32(uint256(0xff));
    }

    function __initializeVaultControlStorage(
        uint256 _limit,
        bool _depositPause,
        bool _withdrawalPause,
        bool _depositWhitelist
    ) internal {
        _setLimit(_limit);
        _setDepositPause(_depositPause);
        _setWithdrawalPause(_withdrawalPause);
        _setDepositWhitelist(_depositWhitelist);
    }

    function depositPause() public view returns (bool) {
        return _vaultStorage().depositPause;
    }

    function withdrawalPause() public view returns (bool) {
        return _vaultStorage().withdrawalPause;
    }

    function limit() public view returns (uint256) {
        return _vaultStorage().limit;
    }

    function depositWhitelist() public view returns (bool) {
        return _vaultStorage().depositWhitelist;
    }

    function isDepositorWhitelisted(address account) public view returns (bool) {
        return _vaultStorage().isDepositorWhitelisted[account];
    }

    function _setLimit(uint256 _limit) internal {
        Storage storage s = _vaultStorage();
        s.limit = _limit;
        emit LimitSet(_limit, block.timestamp, msg.sender);
    }

    function _setDepositPause(bool _paused) internal {
        Storage storage s = _vaultStorage();
        s.depositPause = _paused;
        emit DepositPauseSet(_paused, block.timestamp, msg.sender);
    }

    function _setWithdrawalPause(bool _paused) internal {
        Storage storage s = _vaultStorage();
        s.withdrawalPause = _paused;
        emit WithdrawalPauseSet(_paused, block.timestamp, msg.sender);
    }

    function _setDepositWhitelist(bool _status) internal {
        Storage storage s = _vaultStorage();
        s.depositWhitelist = _status;
        emit DepositWhitelistSet(_status, block.timestamp, msg.sender);
    }

    function _setDepositorWhitelistStatus(address account, bool status) internal {
        Storage storage s = _vaultStorage();
        s.isDepositorWhitelisted[account] = status;
        emit DepositorWhitelistStatusSet(account, status, block.timestamp, msg.sender);
    }

    function _vaultStorage() private view returns (Storage storage $) {
        bytes32 slot = storageSlotRef;
        assembly {
            $.slot := slot
        }
    }
}
