// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/vaults/IVaultControlStorage.sol";

abstract contract VaultControlStorage is IVaultControlStorage, Initializable {
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
        ) & ~bytes32(uint256(0xff));
    }

    /**
     * @notice Initialize the Vault storage.
     * @param _limit Value of limit.
     * @param _depositPause Value of `depositPause` state.
     * @param _withdrawalPause Value of `withdrawalPause` state.
     * @param _depositWhitelist Value of `depositWhitelist` state.
     *
     * @custom:requirements
     * - MUST not be initialzed before.
     *
     * @custom:effects
     * - Emits LimitSet event.
     * - Emits DepositPauseSet event.
     * - Emits WithdrawalPauseSet event.
     * - Emits DepositWhitelistSet event.
     */
    function __initializeVaultControlStorage(
        uint256 _limit,
        bool _depositPause,
        bool _withdrawalPause,
        bool _depositWhitelist
    ) internal onlyInitializing {
        _setLimit(_limit);
        _setDepositPause(_depositPause);
        _setWithdrawalPause(_withdrawalPause);
        _setDepositWhitelist(_depositWhitelist);
    }

    /// @inheritdoc IVaultControlStorage
    function depositPause() public view returns (bool) {
        return _vaultStorage().depositPause;
    }

    /// @inheritdoc IVaultControlStorage
    function withdrawalPause() public view returns (bool) {
        return _vaultStorage().withdrawalPause;
    }

    /// @inheritdoc IVaultControlStorage
    function limit() public view returns (uint256) {
        return _vaultStorage().limit;
    }

    /// @inheritdoc IVaultControlStorage
    function depositWhitelist() public view returns (bool) {
        return _vaultStorage().depositWhitelist;
    }

    /// @inheritdoc IVaultControlStorage
    function isDepositorWhitelisted(address account) public view returns (bool) {
        return _vaultStorage().isDepositorWhitelisted[account];
    }

    /**
     * @notice Sets a new `limit` for the Vault.
     * @param _limit Address the Simbiotic Vault.
     *
     * @custom:effects
     * - Emits LimitSet event.
     */
    function _setLimit(uint256 _limit) internal {
        Storage storage s = _vaultStorage();
        s.limit = _limit;
        emit LimitSet(_limit, block.timestamp, msg.sender);
    }

    /**
     * @notice Sets a new `depositPause` state for the Vault.
     * @param _paused A new value of `depositPause`.
     *
     * @custom:effects
     * - Emits DepositPauseSet event.
     */
    function _setDepositPause(bool _paused) internal {
        Storage storage s = _vaultStorage();
        s.depositPause = _paused;
        emit DepositPauseSet(_paused, block.timestamp, msg.sender);
    }

    /**
     * @notice Sets a new `withdrawalPause` state for the Vault.
     * @param _paused A new value of `withdrawalPause`.
     *
     * @custom:effects
     * - Emits WithdrawalPauseSet event.
     */
    function _setWithdrawalPause(bool _paused) internal {
        Storage storage s = _vaultStorage();
        s.withdrawalPause = _paused;
        emit WithdrawalPauseSet(_paused, block.timestamp, msg.sender);
    }

    /**
     * @notice Sets a new `depositWhitelist` state for the Vault.
     * @param _status A new value of `withdrawalPause`.
     *
     * @custom:effects
     * - Emits DepositWhitelistSet event.
     */
    function _setDepositWhitelist(bool _status) internal {
        Storage storage s = _vaultStorage();
        s.depositWhitelist = _status;
        emit DepositWhitelistSet(_status, block.timestamp, msg.sender);
    }

    /**
     * @notice Sets a new `status` state for the `account` at `isDepositorWhitelisted`.
     * @param account Address of the account.
     * @param status A new status for the `account`.
     *
     * @custom:effects
     * - Emits DepositorWhitelistStatusSet event.
     */
    function _setDepositorWhitelistStatus(address account, bool status) internal {
        Storage storage s = _vaultStorage();
        s.isDepositorWhitelisted[account] = status;
        emit DepositorWhitelistStatusSet(account, status, block.timestamp, msg.sender);
    }

    /**
     * @notice Returns slot `$` of the Vault storage.
     */
    function _vaultStorage() private view returns (Storage storage $) {
        bytes32 slot = storageSlotRef;
        assembly {
            $.slot := slot
        }
    }
}
