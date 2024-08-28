// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AccessControlEnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {ERC4626Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "./IVaultControlStorage.sol";

/**
 * @title IVaultControl
 * @notice Interface defining control of the Vault state.
 */
interface IVaultControl is IVaultControlStorage {
    /**
     * @notice Sets a new `_limit` for the Vault.
     * @param _limit New limit.
     */
    function setLimit(uint256 _limit) external;

    /**
     * @notice Pauses any withdrawals.
     */
    function pauseWithdrawals() external;

    /**
     * @notice Unauses withdrawals.
     */
    function unpauseWithdrawals() external;

    /**
     * @notice Pauses any deposits.
     */
    function pauseDeposits() external;

    /**
     * @notice Unauses deposits.
     */
    function unpauseDeposits() external;

    /**
     * @notice Sets `depositWhitelist` to true.
     */
    function setDepositWhitelist(bool status) external;

    /**
     * @notice Sets `status` for the `account` at whitelist,
     * @param account Address of the account.
     * @param status A new stataus.
     */
    function setDepositorWhitelistStatus(address account, bool status) external;
}
