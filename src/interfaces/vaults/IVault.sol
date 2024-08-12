// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {AccessControlEnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IDefaultCollateral} from "../symbiotic/IDefaultCollateral.sol";
import {ISymbioticVault} from "../symbiotic/ISymbioticVault.sol";
import {IStakerRewards} from "../symbiotic/IStakerRewards.sol";
import {IVaultStorage} from "./IVaultStorage.sol";

interface IVault is IVaultStorage {
    event Deposit(address indexed user, uint256 depositValue, uint256 lpAmount, address referral);
    event NewLimit(uint256 limit);
    event PushToSymbioticBond(uint256 amount);
    event FarmSet(address rewardToken, FarmData farmData);
    event RewardsPushed(address rewardToken, uint256 rewardAmount, uint256 timestamp);
}
