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
        uint256 limit;
        address symbioticVault;
        address withdrawalQueue;
        address admin;
        bool depositPause;
        bool withdrawalPause;
        bool depositWhitelist;
        string name;
        string symbol;
    }

    event RewardsPushed(
        address indexed rewardsToken, uint256 rewardAmount, uint256 curatorFee, uint256 timestamp
    );
}
