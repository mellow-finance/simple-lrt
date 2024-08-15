// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/vaults/IVault.sol";
import {VaultStorage} from "./VaultStorage.sol";
import {SymbioticWithdrawalQueue} from "./SymbioticWithdrawalQueue.sol";
import {ERC4626Math} from "./libraries/ERC4626Math.sol";

// TODO:
// 1. Off by 1 errors (add test for MulDiv rounding e.t.c)
// 2. Tests (unit, int, e2e, migration)
// 3. Make it a Multicall\
// 4. Pause deposits and withdrawals but not transfers
abstract contract Vault is
    IVault,
    VaultStorage,
    AccessManagerUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    using Math for uint256;

    // -------------------------- Guarded params --------------------------

    uint64 public constant SET_LIMIT_ROLE = uint64(uint256(keccak256("SET_LIMIT_ROLE")));

    uint64 public constant PAUSE_TRANSFERS_ROLE = uint64(uint256(keccak256("PAUSE_TRANSFERS_ROLE")));
    uint64 public constant UNPAUSE_TRANSFERS_ROLE =
        uint64(uint256(keccak256("UNPAUSE_TRANSFERS_ROLE")));

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

    function pauseTransfers() external onlyAuthorized {
        _setTransferPause(true);
        _revokeRole(PAUSE_TRANSFERS_ROLE, _msgSender());
    }

    function unpauseTransfers() external onlyAuthorized {
        _setTransferPause(false);
    }

    function pauseDeposits() external onlyAuthorized {
        _setDepositPause(true);
        _revokeRole(PAUSE_DEPOSITS_ROLE, _msgSender());
    }

    function unpauseDeposits() external onlyAuthorized {
        _setDepositPause(false);
    }

    // -------------------------- BALANCES --------------------------

    struct WithdrawalBalances {
        uint256 totalShares;
        // Doesn't include pending and claimable assets
        uint256 totalAssets;
        uint256 stakedShares;
        uint256 stakedAssets;
        uint256 instantShares;
        uint256 instantAssets;
        uint256 pendingAssets;
        uint256 claimableAssets;
    }

    function getWithdrawalBalances() public view returns (WithdrawalBalances memory balances) {
        ISymbioticVault symbioticVault = symbioticVault();
        uint256 symbioticSharesOfVault = symbioticVault.activeSharesOf(address(this));

        balances.instantAssets = IERC20(asset()).balanceOf(address(this))
            + symbioticCollateral().balanceOf(address(this));
        balances.stakedAssets = symbioticVault.activeBalanceOf(address(this));
        // We consider pending and claimable assets out-of-the-vault entities
        balances.pendingAssets = 0;
        balances.claimableAssets = 0;
        balances.totalAssets = balances.instantAssets + balances.stakedAssets
            + balances.pendingAssets + balances.claimableAssets;

        balances.totalShares = totalSupply();
        // We guarantee that this amount of shares is available for instant withdrawal
        // hence Math.Rounding.Floor
        balances.instantShares = balances.instantAssets.mulDiv(
            balances.totalShares, balances.totalAssets, Math.Rounding.Floor
        );
        balances.stakedShares = balances.totalShares - balances.instantShares;
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
        balance.instantAssets = Math.min(balance.totalAssets, totals.instantAssets);
        balance.stakedAssets = balance.totalAssets - balance.instantAssets;
        IWithdrawalQueue withdrawalQueue = withdrawalQueue();
        (, balance.pendingAssets) = withdrawalQueue.pending(account);
        balance.claimableAssets = withdrawalQueue.claimable(account);
        balances.instantShares = balances.instantAssets.mulDiv(
            balances.totalShares, balances.totalAssets, Math.Rounding.Floor
        );
        balances.stakedShares = balances.totalShares - balances.instantShares;
    }

    function previewDeposit(uint256 assets) external view returns (uint256 shares) {
        if (assets == 0) {
            return 0;
        }
        uint256 totalAssets =
            asset().balanceOf(address(this)) + symbioticCollateral().balanceOf(address(this));
        ISymbioticVault symbioticVault = symbioticVault();

        uint256 activeStake = symbioticVault.activeStake();
        uint256 activeShares = symbioticVault.activeShares();
        uint256 vaultShares = symbioticVault.activeSharesOf(address(this));
        uint256 symbioticAssets = vaultShares.mulDiv(activeStake, activeShares, Math.Rounding.Ceil);

        totalAssets += symbioticAssets;

        shares = assets.mulDiv(totalSupply(), totalAssets, Math.Rounding.Floor);
    }

    // function getBalances(address account) external view returns (Balances memory state) {
    //     uint256 totalSupply_ = totalSupply();
    //     state.stakedShares = balanceOf(account);

    //     uint256 assets_ = IERC20(asset()).balanceOf(address(this));
    //     uint256 collateral_ = symbioticCollateral().balanceOf(address(this));
    //     uint256 stake_ = getSymbioticVaultStake(Math.Rounding.Floor); // rounding down
    //     state.stakedAssets = Math.mulDiv(
    //         state.shares,
    //         assets_ + collateral_ + stake_,
    //         totalSupply_,
    //         Math.Rounding.Floor // rounding down
    //     );

    //     instantAssets = Math.min(assets, assets_ + collateral_);
    //     instantShares = Math.mulDiv(
    //         shares,
    //         totalSupply_,
    //         totalSupply_ - stake_,
    //         Math.Rounding.Ceil // rounding up
    //     );

    //     (pendingShares, pendingAssets) = withdrawalQueue().pending(account);
    //     claimableAssets = withdrawalQueue().claimable(account);
    // }

    // Can we build both tvl and getSymVaultStake from the getState?
    function tvl(Math.Rounding rounding) public view returns (uint256 totalValueLocked) {
        // + pending?
        return IERC20(asset()).balanceOf(address(this))
            + symbioticCollateral().balanceOf(address(this)) + getSymbioticVaultStake(rounding);
    }

    function getSymbioticVaultStake(Math.Rounding rounding)
        public
        view
        returns (uint256 vaultActiveStake)
    {
        ISymbioticVault symbioticVault = symbioticVault();
        uint256 vaultActiveShares = symbioticVault.activeSharesOf(address(this));
        uint256 activeStake = symbioticVault.activeStake();
        uint256 activeShares = symbioticVault.activeShares();
        vaultActiveStake = Math.mulDiv(activeStake, vaultActiveShares, activeShares, rounding);
    }

    // -------------------------- ERC4626 --------------------------

    function asset() public view override(VaultStorage, IDelayedERC4626) returns (address) {
        return VaultStorage.asset();
    }

    function totalAssets() public view returns (uint256) {
        return tvl(Math.Rounding.Ceil); // rounding up
    }

    function convertToShares(uint256 asset_) external view returns (uint256) {
        return Math.mulDiv( // rounding down
            asset_,
            totalSupply(),
            tvl(Math.Rounding.Ceil) // rounding up
        );
    }

    function convertToAssets(uint256 shares) external view returns (uint256 assets) {
        return Math.mulDiv( // rounding down
            shares,
            tvl(Math.Rounding.Floor), // rounding down
            totalSupply()
        );
    }

    function maxDeposit(address /* receiver */ ) external view returns (uint256) {
        uint256 totalSupply_ = totalSupply();
        uint256 leftover = limit() - totalSupply_;
        return Math.mulDiv( // rounding down
            leftover,
            tvl(Math.Rounding.Floor), // rounding down
            totalSupply_
        );
    }

    function previewDeposit(uint256 assets) external view returns (uint256) {
        if (assets == 0) {
            return 0;
        }
        return Math.mulDiv( // rounding down
            totalSupply(),
            tvl(Math.Rounding.Floor) + assets, // rounding down
            tvl(Math.Rounding.Ceil) // rounding up
        );
    }

    function initialDeposit(address depositToken, uint256 amount, uint256 initialTotalSupply)
        external
        onlyAuthorized
    {
        require(totalSupply() == 0, "Vault: not initial deposit");
        _update(address(0), address(this), initialTotalSupply);
        _deposit(depositToken, amount);
        pushIntoSymbiotic();
    }

    function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
        return deposit(asset(), assets, 0, receiver, address(0));
    }

    function maxMint(address /* receiver */ ) external view returns (uint256 maxShares) {
        return limit() - totalSupply();
    }

    function previewMint(uint256 shares) public view returns (uint256 assets) {
        if (shares == 0) {
            return 0;
        }
        return Math.mulDiv( // rounding up
            shares,
            tvl(Math.Rounding.Ceil), // rounding up
            totalSupply(),
            Math.Rounding.Ceil
        );
    }

    function mint(uint256 shares, address receiver) external returns (uint256) {
        uint256 assets = previewMint(shares);
        return deposit(asset(), assets, shares, receiver, address(0));
    }

    function maxWithdraw(address account)
        external
        view
        returns (uint256 maxAssets, uint256 maxClaimableAssets_)
    {
        uint256 balance = balanceOf(account);
        if (balance == 0) {
            return (0, 0);
        }

        uint256 totalSupply_ = totalSupply();

        uint256 assets = IERC20(asset()).balanceOf(address(this));
        uint256 collateral = symbioticCollateral().balanceOf(address(this));
        uint256 stake = getSymbioticVaultStake(Math.Rounding.Floor); // rounding down

        maxAssets = Math.mulDiv( // rounding down
        balance, assets + collateral + stake, totalSupply_);

        if (maxAssets > assets + collateral) {
            maxClaimableAssets_ = maxAssets - assets + collateral;
            maxAssets -= maxClaimableAssets_;
        }
    }

    function previewWithdraw(uint256 assets_)
        public
        view
        returns (uint256 shares, uint256 claimableAssets)
    {
        uint256 assets = IERC20(asset()).balanceOf(address(this));
        uint256 collateral = symbioticCollateral().balanceOf(address(this));
        uint256 stake = getSymbioticVaultStake(Math.Rounding.Ceil); // rounding up
        shares = Math.mulDiv( // rounding up
            totalSupply(),
            assets_,
            assets + collateral + stake, // rounding up
            Math.Rounding.Ceil
        );
        if (assets + collateral < assets_) {
            claimableAssets = assets_ - assets + collateral;
        }
    }

    function withdraw(uint256 assets, address receiver, address account)
        external
        returns (uint256 shares, uint256 claimableAssets)
    {
        require(msg.sender == account, "Vault: forbidden");
        (shares,) = previewWithdraw(assets);
        return redeem(shares, receiver);
    }

    function redeem(uint256 shares, address receiver, address account)
        external
        returns (uint256 assets, uint256 claimableAssets)
    {
        require(msg.sender == account, "Vault: forbidden");
        return redeem(shares, receiver);
    }

    function maxRedeem(address account) external view returns (uint256 maxShares) {
        return balanceOf(account);
    }

    function previewRedeem(uint256 shares)
        external
        view
        returns (uint256 assets, uint256 claimableAssets)
    {
        uint256 totalSupply_ = totalSupply();
        uint256 assets_ = IERC20(asset()).balanceOf(address(this));
        uint256 collateral = symbioticCollateral().balanceOf(address(this));
        uint256 stake = getSymbioticVaultStake(Math.Rounding.Floor); // rounding down
        assets = Math.mulDiv( // rounding down
        shares, assets_ + collateral + stake, totalSupply_);
        if (assets_ + collateral < assets) {
            claimableAssets = assets - assets_ + collateral;
            assets -= claimableAssets;
        }
    }

    function maxClaimableAssets(address account) external view returns (uint256 claimableAssets_) {
        claimableAssets_ = withdrawalQueue().claimable(account);
    }

    function claimAssets(address recipient, address account)
        external
        returns (uint256 claimedAssets)
    {
        claimedAssets = withdrawalQueue().claim(account, recipient);
    }

    function maxPendingAssets(address account) external view returns (uint256 pendingAssets_) {
        (, pendingAssets_) = withdrawalQueue().pending(account);
    }

    function deposit(
        address depositToken,
        uint256 amount,
        uint256 minShares,
        address recipient,
        address referral
    ) public payable returns (uint256 shares) {
        if (depositPause()) {
            revert("Vault: paused");
        }
        uint256 totalSupply_ = totalSupply();
        uint256 valueBefore = tvl(Math.Rounding.Ceil);
        _deposit(depositToken, amount);
        uint256 valueAfter = tvl(Math.Rounding.Floor);
        if (valueAfter <= valueBefore) {
            revert("Vault: invalid deposit amount");
        }
        uint256 depositValue = valueAfter - valueBefore;
        shares = Math.mulDiv(totalSupply_, depositValue, valueBefore);
        if (minShares > shares) {
            revert("Vault: minShares > shares");
        }
        if (shares + totalSupply_ > limit()) {
            revert("Vault: vault limit reached");
        } else if (shares == 0) {
            revert("Vault: zero shares");
        }
        pushIntoSymbiotic();

        _update(address(0), recipient, shares);
        emit Deposit(recipient, depositValue, shares, referral);
    }

    function redeem(uint256 lpAmount, address recipient)
        public
        returns (uint256 withdrawnAmount, uint256 amountToClaim)
    {
        lpAmount = Math.min(lpAmount, balanceOf(_msgSender()));
        if (lpAmount == 0) {
            return (0, 0);
        }

        address asset_ = asset();
        IDefaultCollateral symbioticCollateral = symbioticCollateral();
        uint256 tokenValue = IERC20(asset_).balanceOf(address(this));
        uint256 collateralValue = symbioticCollateral.balanceOf(address(this));
        uint256 symbioticVaultStake = getSymbioticVaultStake(Math.Rounding.Floor);

        uint256 totalValue = tokenValue + collateralValue + symbioticVaultStake;
        amountToClaim = Math.mulDiv(lpAmount, totalValue, totalSupply());
        if (tokenValue != 0) {
            uint256 tokenAmount = Math.min(amountToClaim, tokenValue);
            IERC20(asset_).safeTransfer(recipient, tokenAmount);
            amountToClaim -= tokenAmount;
            withdrawnAmount += tokenAmount;
            if (amountToClaim == 0) {
                return (withdrawnAmount, 0);
            }
        }

        if (collateralValue != 0) {
            uint256 collateralAmount = Math.min(amountToClaim, collateralValue);
            symbioticCollateral.withdraw(recipient, collateralAmount);
            amountToClaim -= collateralAmount;
            withdrawnAmount += collateralAmount;
            if (amountToClaim == 0) {
                return (withdrawnAmount, 0);
            }
        }

        ISymbioticVault symbioticVault = symbioticVault();

        uint256 sharesAmount = Math.mulDiv(
            amountToClaim,
            symbioticVault.activeShares(),
            symbioticVault.activeStake(),
            Math.Rounding.Floor
        );

        symbioticVault.withdraw(recipient, sharesAmount);
    }

    function pushIntoSymbiotic() public virtual {
        IERC20 token = IERC20(asset());
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

        uint256 curatorFee = Math.mulDiv(rewardAmount, data.curatorFeeD4, 1e4);
        if (curatorFee != 0) {
            rewardToken.safeTransfer(data.curatorTreasury, curatorFee);
        }
        // Guranteed to be >= 0 since data.curatorFeeD4 <= 1e4
        rewardAmount = rewardAmount - curatorFee;
        if (rewardAmount != 0) {
            rewardToken.safeTransfer(data.distributionFarm, rewardAmount);
        }
        // TODO: Add fees data
        emit RewardsPushed(address(rewardToken), rewardAmount, block.timestamp);
    }

    // -------------------------- ERC20 Compatibility --------------------------

    function totalSupply() public view virtual returns (uint256);

    function balanceOf(address account) public view virtual returns (uint256);

    function _update(address, /* from */ address, /* to */ uint256 /* amount */ )
        internal
        virtual
    {
        if (transferPause()) {
            revert("Vault: paused");
        }
    }

    function _deposit(address depositToken, uint256 amount) internal virtual;

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
