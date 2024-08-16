// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {IMellowSymbioticVaultStorage} from "./IMellowSymbioticVaultStorage.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {AccessManagerUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {ERC4626Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IDefaultCollateral} from "../symbiotic/IDefaultCollateral.sol";
import {IStakerRewards} from "../symbiotic/IStakerRewards.sol";
import {ISymbioticVault} from "../symbiotic/ISymbioticVault.sol";

interface IMellowSymbioticVault is IMellowSymbioticVaultStorage {
    struct InitParams {
        address symbioticVault;
        address withdrawalQueue;
        uint256 limit;
        bool depositPause;
        bool withdrawalPause;
        bool depositWhitelist;
        address admin;
        string name;
        string symbol;
    }

    struct WithdrawalBalances {
        uint256 totalShares;
        uint256 totalAssets; // Doesn't include pending and claimable assets
        uint256 stakedShares;
        uint256 stakedAssets;
        uint256 instantShares;
        uint256 instantAssets;
    }

    event RewardsPushed(
        address indexed rewardsToken, uint256 rewardAmount, uint256 curatorFee, uint256 timestamp
    );
}
