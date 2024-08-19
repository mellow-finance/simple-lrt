// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AccessControlEnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {ERC4626Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

import {MulticallUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "./IVaultControlStorage.sol";

interface IVaultControl is IVaultControlStorage {
    event ReferralDeposit(uint256 asset, address reciever, address referral);

    function deposit(uint256 assets, address receiver, address referral)
        external
        returns (uint256 shares);
}
