// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/vaults/IVault.sol";
import {VaultStorage} from "./VaultStorage.sol";
import {SymbioticWithdrawalQueue, IWithdrawalQueue} from "./SymbioticWithdrawalQueue.sol";

import {ERC4626Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

// TODO:
// 1. Off by 1 errors (add test for MulDiv rounding e.t.c)
// 2. Tests (unit, int, e2e, migration)
// 3. Add Factory
abstract contract Vault is
    IVault,
    VaultStorage,
    ERC4626Upgradeable,
    ReentrancyGuardUpgradeable,
    AccessManagerUpgradeable
{
    using SafeERC20 for IERC20;
    using Math for uint256;

    // -------------------------- Guarded params --------------------------

    uint64 public constant SET_LIMIT_ROLE = uint64(uint256(keccak256("SET_LIMIT_ROLE")));

    uint64 public constant PAUSE_WITHDRAWALS_ROLE =
        uint64(uint256(keccak256("PAUSE_WITHDRAWALS_ROLE")));
    uint64 public constant UNPAUSE_WITHDRAWALS_ROLE =
        uint64(uint256(keccak256("UNPAUSE_WITHDRAWALS_ROLE")));

    uint64 public constant PAUSE_DEPOSITS_ROLE = uint64(uint256(keccak256("PAUSE_DEPOSITS_ROLE")));
    uint64 public constant UNPAUSE_DEPOSITS_ROLE =
        uint64(uint256(keccak256("UNPAUSE_DEPOSITS_ROLE")));

    function setLimit(uint256 _limit) external onlyAuthorized {
        if (totalSupply() > _limit) {
            revert("Vault: totalSupply exceeds new limit");
        }
        _setLimit(_limit);
        emit NewLimit(_limit);
    }

    function pauseWithdrawals() external onlyAuthorized {
        _setWithdrawalPause(true);
        _revokeRole(PAUSE_WITHDRAWALS_ROLE, _msgSender());
    }

    function unpauseWithdrawals() external onlyAuthorized {
        _setWithdrawalPause(false);
    }

    function pauseDeposits() external onlyAuthorized {
        _setDepositPause(true);
        _revokeRole(PAUSE_DEPOSITS_ROLE, _msgSender());
    }

    function unpauseDeposits() external onlyAuthorized {
        _setDepositPause(false);
    }

    function setFarm(address rewardToken, FarmData memory farmData) external onlyAuthorized {
        _setFarmChecks(rewardToken, farmData);
        _setFarm(rewardToken, farmData);
    }

    function removeFarm(address rewardToken) external onlyAuthorized {
        _removeFarm(rewardToken);
    }

    // // -------------------------- BALANCES --------------------------

    struct WithdrawalBalances {
        uint256 totalShares;
        uint256 totalAssets; // Doesn't include pending and claimable assets
        uint256 stakedShares;
        uint256 stakedAssets;
        uint256 instantShares;
        uint256 instantAssets;
    }
    // Maybe makes sense to make 2 methods getStakedBalances and getInstantBalances

    function getWithdrawalBalances() public view returns (WithdrawalBalances memory balances) {
        address this_ = address(this);
        ISymbioticVault symbioticVault = symbioticVault();

        balances.instantAssets =
            IERC20(asset()).balanceOf(this_) + symbioticCollateral().balanceOf(this_);
        balances.stakedAssets = symbioticVault.activeBalanceOf(this_);
        balances.totalAssets = balances.instantAssets + balances.stakedAssets;

        balances.totalShares = totalSupply();
        // We guarantee that this amount of shares is available for instant withdrawal
        // hence Math.Rounding.Floor
        balances.instantShares = balances.instantAssets.mulDiv(
            balances.totalShares, balances.totalAssets, Math.Rounding.Floor
        );
        balances.stakedShares = balances.totalShares - balances.instantShares;
    }

    // just 4626-like function
    function previewClaim(address account)
        external
        view
        returns (uint256 pendingAssets, uint256 claimableAssets)
    {
        IWithdrawalQueue withdrawalQueue = withdrawalQueue();
        pendingAssets = withdrawalQueue.pendingAssetsOf(account);
        claimableAssets = withdrawalQueue.claimableAssetsOf(account);
    }

    function getWithdrawalBalance(address account)
        public
        view
        returns (WithdrawalBalances memory balance)
    {
        WithdrawalBalances memory totals = getWithdrawalBalances();
        balance.totalShares = balanceOf(account);
        balance.totalAssets =
            balance.totalShares.mulDiv(totals.totalAssets, totals.totalShares, Math.Rounding.Floor);
        balance.instantAssets = balance.totalAssets.min(totals.instantAssets);
        balance.stakedAssets = balance.totalAssets - balance.instantAssets;
        balance.instantShares = balance.instantAssets.mulDiv(
            balance.totalShares, balance.totalAssets, Math.Rounding.Floor
        );
        balance.stakedShares = balance.totalShares - balance.instantShares;
    }

    function totalAssets() public view virtual override(ERC4626Upgradeable) returns (uint256) {
        return IERC20(asset()).balanceOf(address(this))
            + symbioticCollateral().balanceOf(address(this))
            + symbioticVault().activeBalanceOf(address(this));
    }

    function maxDeposit(address account) public view virtual override returns (uint256) {
        return convertToAssets(maxMint(account));
    }

    function maxMint(address /* account */ ) public view virtual override returns (uint256) {
        // TODO: Add whitelist
        uint256 limit_ = limit();
        uint256 totalSupply_ = totalSupply();
        return limit_ >= totalSupply_ ? limit_ - totalSupply_ : 0;
    }

    function maxRedeem(address account) public view virtual override returns (uint256) {
        return convertToShares(maxWithdrawal(account));
    }

    function maxWithdrawal(address account) public view virtual returns (uint256) {
        // Dont use claimable here as it distorts the share price
        return getWithdrawalBalance(account).instantAssets;
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        virtual
        override
    {
        super._deposit(caller, receiver, assets, shares);
        pushIntoSymbiotic();
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        // We cannot claim from withdrawalQueue here, as it distorts the share price.
        // By that moment the user can have 0 shares but still have pending assets.
        // So this is only for instant + staked.

        require(owner == caller, "Vault: owner != caller");
        address this_ = address(this);
        uint256 assets_ = IERC20(asset()).balanceOf(this_);
        if (assets_ >= assets) {
            return super._withdraw(caller, receiver, owner, assets, shares);
        }
        uint256 collaterals_ = symbioticCollateral().balanceOf(this_);
        // Check if it makes sense to convert everything
        symbioticCollateral().withdraw(this_, collaterals_);
        assets_ = IERC20(asset()).balanceOf(this_);
        if (assets_ >= assets) {
            return super._withdraw(caller, receiver, owner, assets, shares);
        }
        // Migrated from ERC4626
        if (caller != owner) {
            super._spendAllowance(owner, caller, shares);
        }
        // Check that it works correctly
        symbioticVault().withdraw(address(withdrawalQueue()), assets - assets_);
        super._burn(owner, shares);
        emit IERC4626.Withdraw(caller, receiver, owner, assets, shares);

        // require(owner == caller, "Vault: owner != caller");
        // address this_ = address(this);
        // uint256 assets_ = IERC20(asset()).balanceOf(this_);
        // if (assets_ < assets) {
        //     uint256 collaterals_ = symbioticCollateral().balanceOf(this_);
        //     if (assets_ + collaterals_ < assets) {
        //         collaterals_ +=
        //             withdrawalQueue().claim(owner, this_, assets - assets_ - collaterals_);
        //         if (assets_ + collaterals_ < assets) {
        //             revert("Vault: insufficient assets");
        //         }
        //         symbioticCollateral().withdraw(this_, collaterals_);
        //     } else {
        //         symbioticCollateral().withdraw(this_, assets - assets_);
        //     }
        // }
        // super._withdraw(caller, receiver, owner, assets, shares);
    }

    function pushIntoSymbiotic() public virtual {
        IERC20 asset_ = IERC20(asset());
        uint256 assetAmount = asset_.balanceOf(address(this));
        IDefaultCollateral symbioticCollateral = symbioticCollateral();
        ISymbioticVault symbioticVault = symbioticVault();
        uint256 leftover = symbioticCollateral.limit() - symbioticCollateral.totalSupply();
        assetAmount = assetAmount.min(leftover);
        if (assetAmount == 0) {
            return;
        }
        asset_.safeIncreaseAllowance(address(symbioticCollateral), assetAmount);
        uint256 amount = symbioticCollateral.deposit(address(this), assetAmount);
        if (amount != assetAmount) {
            asset_.forceApprove(address(symbioticCollateral), 0);
        }

        uint256 collateralAmount = symbioticCollateral.balanceOf(address(this));
        IERC20(symbioticCollateral).safeIncreaseAllowance(address(symbioticVault), collateralAmount);
        (uint256 stakedAmount,) = symbioticVault.deposit(address(this), collateralAmount);
        if (collateralAmount != stakedAmount) {
            IERC20(symbioticCollateral).forceApprove(address(symbioticVault), 0);
        }
    }

    function pushRewards(IERC20 rewardToken, bytes calldata symbioticRewardsData)
        external
        nonReentrant
    {
        FarmData memory data = symbioticFarm(address(rewardToken));
        require(data.symbioticFarm != address(0), "Vault: farm not set");
        uint256 amountBefore = rewardToken.balanceOf(address(this));
        IStakerRewards(data.symbioticFarm).claimRewards(
            address(this), address(rewardToken), symbioticRewardsData
        );
        uint256 rewardAmount = rewardToken.balanceOf(address(this)) - amountBefore;
        if (rewardAmount == 0) {
            return;
        }

        uint256 curatorFee = rewardAmount.mulDiv(data.curatorFeeD4, 1e4);
        if (curatorFee != 0) {
            rewardToken.safeTransfer(data.curatorTreasury, curatorFee);
        }
        // Guranteed to be >= 0 since data.curatorFeeD4 <= 1e4
        rewardAmount = rewardAmount - curatorFee;
        if (rewardAmount != 0) {
            rewardToken.safeTransfer(data.distributionFarm, rewardAmount);
        }
        emit RewardsPushed(address(rewardToken), rewardAmount, curatorFee, block.timestamp);
    }

    function _update(address from, address to, uint256 value) internal virtual override {
        uint256 pendingShares = convertToShares(withdrawalQueue().balanceOf(from));
        if (balanceOf(from) < pendingShares) {
            revert("Vault: insufficient balance");
        }
        super._update(from, to, value);
    }

    function _setFarmChecks(address rewardToken, FarmData memory farmData) internal virtual {
        if (
            rewardToken == address(this) || rewardToken == address(symbioticCollateral())
                || rewardToken == address(symbioticVault())
        ) {
            revert("Vault: forbidden reward token");
        }
        if (farmData.curatorFeeD4 > 1e4) {
            revert("Vault: invalid curator fee");
        }
    }
}
