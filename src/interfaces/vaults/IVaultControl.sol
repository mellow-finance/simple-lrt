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

interface IVaultControl is IVaultControlStorage {
    function setLimit(uint256 _limit) external;

    function pauseWithdrawals() external;

    function unpauseWithdrawals() external;

    function pauseDeposits() external;

    function unpauseDeposits() external;

    function setDepositWhitelist(bool status) external;

    function setDepositorWhitelistStatus(address account, bool status) external;
}
