// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {VaultControlStorage} from "./VaultControlStorage.sol";

import "./interfaces/vaults/IVaultControl.sol";

abstract contract VaultControl is
    IVaultControl,
    VaultControlStorage,
    ReentrancyGuardUpgradeable,
    AccessControlEnumerableUpgradeable
{
    // roles

    bytes32 private constant SET_LIMIT_ROLE = keccak256("SET_LIMIT_ROLE");
    bytes32 private constant PAUSE_WITHDRAWALS_ROLE = keccak256("PAUSE_WITHDRAWALS_ROLE");
    bytes32 private constant UNPAUSE_WITHDRAWALS_ROLE = keccak256("UNPAUSE_WITHDRAWALS_ROLE");
    bytes32 private constant PAUSE_DEPOSITS_ROLE = keccak256("PAUSE_DEPOSITS_ROLE");
    bytes32 private constant UNPAUSE_DEPOSITS_ROLE = keccak256("UNPAUSE_DEPOSITS_ROLE");
    bytes32 private constant SET_DEPOSIT_WHITELIST_ROLE = keccak256("SET_DEPOSIT_WHITELIST_ROLE");
    bytes32 private constant SET_DEPOSITOR_WHITELIST_STATUS_ROLE =
        keccak256("SET_DEPOSITOR_WHITELIST_STATUS_ROLE");

    function __initializeVaultControl(
        address _admin,
        uint256 _limit,
        bool _depositPause,
        bool _withdrawalPause,
        bool _depositWhitelist
    ) internal {
        __ReentrancyGuard_init();
        __AccessControlEnumerable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);

        __initializeVaultControlStorage(_limit, _depositPause, _withdrawalPause, _depositWhitelist);
    }

    // setters getters

    function setLimit(uint256 _limit) external onlyRole(SET_LIMIT_ROLE) {
        // I don't think we need this check
        // require(totalSupply() <= _limit, "Vault: totalSupply exceeds new limit");
        _setLimit(_limit);
    }

    function pauseWithdrawals() external onlyRole(PAUSE_WITHDRAWALS_ROLE) {
        _setWithdrawalPause(true);
        _revokeRole(PAUSE_WITHDRAWALS_ROLE, _msgSender());
    }

    function unpauseWithdrawals() external onlyRole(UNPAUSE_WITHDRAWALS_ROLE) {
        _setWithdrawalPause(false);
    }

    function pauseDeposits() external onlyRole(PAUSE_DEPOSITS_ROLE) {
        _setDepositPause(true);
        _revokeRole(PAUSE_DEPOSITS_ROLE, _msgSender());
    }

    function unpauseDeposits() external onlyRole(UNPAUSE_DEPOSITS_ROLE) {
        _setDepositPause(false);
    }

    function setDepositWhitelist(bool status) external onlyRole(SET_DEPOSIT_WHITELIST_ROLE) {
        _setDepositWhitelist(status);
    }

    function setDepositorWhitelistStatus(address account, bool status)
        external
        onlyRole(SET_DEPOSITOR_WHITELIST_STATUS_ROLE)
    {
        _setDepositorWhitelistStatus(account, status);
    }
}
