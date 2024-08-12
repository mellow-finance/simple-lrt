// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IDefaultCollateral} from "./IDefaultCollateral.sol";
import {ISymbioticVault} from "./ISymbioticVault.sol";
import {IStakerRewards} from "./IStakerRewards.sol";
import {IVaultStorage} from "./IVaultStorage.sol";

interface IVault is IVaultStorage {
    function setLimit(uint256 _limit) external;

    function pause() external;

    function unpause() external;
    function pushRewards(IERC20 rewardToken, bytes calldata symbioticRewardsData) external;
    function getSymbioticVaultStake(Math.Rounding rounding) external view returns (uint256 vaultActiveStake);

    function tvl(Math.Rounding rounding) external view returns (uint256 totalValueLocked);

    function deposit(address depositToken, uint256 amount, address recipient, address referral) external payable;

    function withdraw(uint256 lpAmount) external returns (uint256 withdrawnAmount, uint256 amountToClaim);

    function pushIntoSymbiotic() external;

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    event Deposit(address indexed user, uint256 depositValue, uint256 lpAmount, address referral);
    event NewLimit(uint256 limit);
    event PushToSymbioticBond(uint256 amount);
    event FarmSet(address rewardToken, FarmData farmData);
    event RewardsPushed(address rewardToken, uint256 rewardAmount, uint256 timestamp);
}
