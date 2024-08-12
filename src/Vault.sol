// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.26;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IDefaultCollateral} from "./interfaces/IDefaultCollateral.sol";
import {ISymbioticVault} from "./interfaces/ISymbioticVault.sol";
import {IStakerRewards} from "./interfaces/IStakerRewards.sol";
import {VaultStorage} from "./VaultStorage.sol";

// TODO:
// 1. Off by 1 errors (add test for MulDiv rounding e.t.c)
// 2. Tests (unit, int, e2e, migration)

abstract contract Vault is VaultStorage {
    using SafeERC20 for IERC20;

    modifier onlyOwner() {
        require(msg.sender == owner(), "BaseVault: forbidden");
        _;
    }

    function setLimit(uint256 _limit) external onlyOwner {
        if (totalSupply() > _limit) {
            revert("BaseVault: totalSupply exceeds new limit");
        }
        _setLimit(_limit);
        emit NewLimit(_limit);
    }

    function pause() external onlyOwner {
        _setPaused(true);
    }

    function unpause() external onlyOwner {
        _setPaused(false);
    }

    function pushRewards(IERC20 rewardToken, bytes calldata symbioticRewardsData) external {
        FarmData memory data = symbioticFarm(address(rewardToken));
        require(data.symbioticFarm != address(0), "Vault: farm not set");
        uint256 amountBefore = rewardToken.balanceOf(address(this));
        IStakerRewards(data.symbioticFarm).claimRewards(address(this), address(rewardToken), symbioticRewardsData);
        uint256 rewardAmount = rewardToken.balanceOf(address(this)) - amountBefore;
        if (rewardAmount == 0) return;

        uint256 curatorFee = Math.mulDiv(rewardAmount, data.curatorFeeD4, 1e4);
        if (curatorFee != 0) {
            rewardToken.safeTransfer(data.curatorTreasury, curatorFee);
        }
        if (rewardAmount != curatorFee) {
            rewardToken.safeTransfer(data.distributionFarm, rewardAmount - curatorFee);
        }
        emit RewardsPushed(address(rewardToken), rewardAmount, block.timestamp);
    }

    function getSymbioticVaultStake(Math.Rounding rounding) public view returns (uint256 vaultActiveStake) {
        ISymbioticVault symbioticVault = symbioticVault();
        uint256 vaultActiveShares = symbioticVault.activeSharesOf(address(this));
        uint256 activeStake = symbioticVault.activeStake();
        uint256 activeShares = symbioticVault.activeShares();
        vaultActiveStake = Math.mulDiv(activeStake, vaultActiveShares, activeShares, rounding);
    }

    function tvl(Math.Rounding rounding) public view returns (uint256 totalValueLocked) {
        return IERC20(token()).balanceOf(address(this)) + symbioticCollateral().balanceOf(address(this))
            + getSymbioticVaultStake(rounding);
    }

    function deposit(address depositToken, uint256 amount, address recipient, address referral) external payable {
        uint256 totalSupply_ = totalSupply();
        uint256 valueBefore = tvl(Math.Rounding.Ceil);
        _deposit(depositToken, amount);
        if (depositToken != token()) revert("BaseVault: invalid deposit token");
        uint256 valueAfter = tvl(Math.Rounding.Floor);
        if (valueAfter <= valueBefore) {
            revert("BaseVault: invalid deposit amount");
        }
        uint256 depositValue = valueAfter - valueBefore;
        uint256 lpAmount = Math.mulDiv(totalSupply_, depositValue, valueBefore);
        if (lpAmount + totalSupply_ > limit()) {
            revert("BaseVault: vault limit reached");
        } else if (lpAmount == 0) {
            revert("BaseVault: zero lpAmount");
        }
        pushIntoSymbiotic();

        _doMint(recipient, lpAmount);
        emit Deposit(recipient, depositValue, lpAmount, referral);
    }

    function withdraw(uint256 lpAmount) external returns (uint256 withdrawnAmount, uint256 amountToClaim) {
        lpAmount = Math.min(lpAmount, balanceOf(msg.sender));
        if (lpAmount == 0) return (0, 0);
        _doBurn(msg.sender, lpAmount);

        address token = token();
        IDefaultCollateral symbioticCollateral = symbioticCollateral();
        uint256 tokenValue = IERC20(token).balanceOf(address(this));
        uint256 collateralValue = symbioticCollateral.balanceOf(address(this));
        uint256 symbioticVaultStake = getSymbioticVaultStake(Math.Rounding.Floor);

        uint256 totalValue = tokenValue + collateralValue + symbioticVaultStake;
        amountToClaim = Math.mulDiv(lpAmount, totalValue, totalSupply());
        if (tokenValue != 0) {
            uint256 tokenAmount = Math.min(amountToClaim, tokenValue);
            IERC20(token).safeTransfer(msg.sender, tokenAmount);
            amountToClaim -= tokenAmount;
            withdrawnAmount += tokenAmount;
            if (amountToClaim == 0) return (withdrawnAmount, 0);
        }

        if (collateralValue != 0) {
            uint256 collateralAmount = Math.min(amountToClaim, collateralValue);
            symbioticCollateral.withdraw(msg.sender, collateralAmount);

            amountToClaim -= collateralAmount;
            withdrawnAmount += collateralAmount;

            if (amountToClaim == 0) return (withdrawnAmount, 0);
        }

        ISymbioticVault symbioticVault = symbioticVault();

        uint256 sharesAmount =
            Math.mulDiv(amountToClaim, symbioticVault.activeShares(), symbioticVault.activeStake(), Math.Rounding.Floor);

        symbioticVault.withdraw(msg.sender, sharesAmount);
    }

    function pushIntoSymbiotic() public {
        IERC20 token = IERC20(token());
        uint256 assetAmount = token.balanceOf(address(this));
        IDefaultCollateral symbioticCollateral = symbioticCollateral();
        ISymbioticVault symbioticVault = symbioticVault();
        uint256 leftover = symbioticCollateral.limit() - symbioticCollateral.totalSupply();
        assetAmount = Math.min(assetAmount, leftover);
        if (assetAmount == 0) {
            return;
        }
        token.safeIncreaseAllowance(address(symbioticCollateral), assetAmount);
        uint256 amount = symbioticCollateral.deposit(address(this), assetAmount);
        if (amount != assetAmount) {
            token.forceApprove(address(symbioticCollateral), 0);
        }

        uint256 bondAmount = symbioticCollateral.balanceOf(address(this));
        IERC20(symbioticCollateral).safeIncreaseAllowance(address(symbioticVault), bondAmount);
        (uint256 stakedAmount,) = symbioticVault.deposit(address(this), bondAmount);
        if (bondAmount != stakedAmount) {
            IERC20(symbioticCollateral).forceApprove(address(symbioticVault), 0);
        }
    }

    function _setFarmChecks(address rewardToken, FarmData memory farmData) internal virtual {
        if (
            rewardToken == token() || rewardToken == address(this) || rewardToken == address(symbioticCollateral())
                || rewardToken == address(symbioticVault())
        ) {
            revert("Vault: forbidden reward token");
        }
        if (farmData.curatorFeeD4 > 1e4) {
            revert("Vault: invalid curator fee");
        }
    }

    function totalSupply() public view virtual returns (uint256);

    function balanceOf(address account) public view virtual returns (uint256);

    function _doMint(address account, uint256 amount) internal virtual;

    function _doBurn(address account, uint256 amount) internal virtual;

    function _deposit(address depositToken, uint256 amount) internal virtual;

    event Deposit(address indexed user, uint256 depositValue, uint256 lpAmount, address referral);
    event NewLimit(uint256 limit);
    event PushToSymbioticBond(uint256 amount);
    event FarmSet(address rewardToken, FarmData farmData);
    event RewardsPushed(address rewardToken, uint256 rewardAmount, uint256 timestamp);
}
