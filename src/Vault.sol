// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/vaults/IVault.sol";
import {VaultStorage} from "./VaultStorage.sol";

// TODO:
// 1. Off by 1 errors (add test for MulDiv rounding e.t.c)
// 2. Tests (unit, int, e2e, migration)
abstract contract Vault is
    IVault,
    VaultStorage,
    AccessManagerUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

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
        if (rewardAmount != curatorFee) {
            rewardToken.safeTransfer(data.distributionFarm, rewardAmount - curatorFee);
        }
        emit RewardsPushed(address(rewardToken), rewardAmount, block.timestamp);
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

    function tvl(Math.Rounding rounding) public view returns (uint256 totalValueLocked) {
        return IERC20(asset()).balanceOf(address(this))
            + symbioticCollateral().balanceOf(address(this)) + getSymbioticVaultStake(rounding);
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

    function maxWithdraw(address owner)
        external
        view
        returns (uint256 maxAssets, uint256 maxClaimableAssets_)
    {
        uint256 balance = balanceOf(owner);
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

    function withdraw(uint256 assets, address receiver, address owner)
        external
        returns (uint256 shares, uint256 claimableAssets)
    {
        require(msg.sender == owner, "Vault: forbidden");
        (shares,) = previewWithdraw(assets);
        return withdraw(shares, receiver);
    }

    function maxRedeem(address owner) external view returns (uint256 maxShares) {
        return balanceOf(owner);
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

    function redeem(uint256 shares, address receiver, address owner)
        external
        returns (uint256 assets, uint256 claimableAssets)
    {
        require(msg.sender == owner, "Vault: forbidden");
        return withdraw(shares, receiver);
    }

    function maxClaimableRewards(address rewardToken, address owner)
        external
        view
        returns (uint256 claimableRewards)
    {
        revert();
    }

    function claimRewards(address rewardToken, address receiver, address owner)
        external
        returns (uint256 claimedRewards)
    {
        revert();
    }

    function maxClaimableAssets(address owner) external view returns (uint256 claimableAssets) {
        /*
            we need accounting for claimable and pending for end of epoch assets
        */
    }

    function claim(address receiver, address owner) external returns (uint256 claimedAssets) {}

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

    function withdraw(uint256 lpAmount, address recipient)
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

    function pushIntoSymbiotic() public {
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
}
