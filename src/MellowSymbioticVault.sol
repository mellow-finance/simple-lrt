// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {MellowSymbioticVaultStorage} from "./MellowSymbioticVaultStorage.sol";
import {VaultControl, VaultControlStorage} from "./VaultControl.sol";
import "./interfaces/vaults/IMellowSymbioticVault.sol";

// TODO:
// 1. Off by 1 errors (add test for MulDiv rounding e.t.c)
// 2. Tests (unit, int, e2e, migration)
// 3. check initializers
// 4. check WithdrawalQueue invariant
contract MellowSymbioticVault is
    IMellowSymbioticVault,
    VaultControl,
    MellowSymbioticVaultStorage
{
    using SafeERC20 for IERC20;
    using Math for uint256;

    constructor(bytes32 name_, uint256 version_)
        MellowSymbioticVaultStorage(name_, version_)
        VaultControlStorage(name_, version_)
    {}

    // initializer

    function initialize(InitParams memory initParams) public virtual initializer {
        __ERC20_init(initParams.name, initParams.symbol);

        __initializeRoles(initParams.admin);
        __initializeMellowSymbioticVaultStorage(
            initParams.symbioticVault, initParams.withdrawalQueue
        );
        __initializeVaultControlStorage(
            initParams.limit,
            initParams.depositPause,
            initParams.withdrawalPause,
            initParams.depositWhitelist
        );
    }

    // roles

    bytes32 public constant SET_FARM_ROLE = keccak256("SET_FARM_ROLE");
    bytes32 public constant REMOVE_FARM_ROLE = keccak256("REMOVE_FARM_ROLE");

    // setters getters

    function setFarm(address rewardToken, FarmData memory farmData)
        external
        onlyAuthorized(SET_FARM_ROLE)
    {
        _setFarmChecks(rewardToken, farmData);
        _setFarm(rewardToken, farmData);
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

    // ERC4626 overrides

    function totalAssets() public view virtual override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this))
            + symbioticCollateral().balanceOf(address(this))
            + symbioticVault().activeBalanceOf(address(this));
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
        uint256 instant_ = collaterals_ + assets_;
        if (instant_ >= assets) {
            symbioticCollateral().withdraw(this_, assets - assets_);
            assets = assets.min(IERC20(asset()).balanceOf(this_));
            return super._withdraw(caller, receiver, owner, assets, shares);
        }

        symbioticCollateral().withdraw(this_, collaterals_);
        uint256 leftover = assets - instant_;
        symbioticVault().withdraw(address(withdrawalQueue()), leftover);
        withdrawalQueue().request(owner, leftover);

        instant_ = assets.min(IERC20(asset()).balanceOf(this_));
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        _burn(owner, shares);
        SafeERC20.safeTransfer(IERC20(asset()), receiver, instant_);

        // emitting event with transfered + new pending assets
        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    function _update(address from, address to, uint256 value) internal virtual override {
        uint256 pendingShares = convertToShares(withdrawalQueue().balanceOf(from));
        if (balanceOf(from) < pendingShares) {
            revert("Vault: insufficient balance");
        }
        super._update(from, to, value);
    }

    // withdrawalQueue proxy functions

    function claimableAssetsOf(address account) external view returns (uint256 claimableAssets) {
        claimableAssets = withdrawalQueue().claimableAssetsOf(account);
    }

    function pendingAssetsOf(address account) external view returns (uint256 pendingAssets) {
        pendingAssets = withdrawalQueue().pendingAssetsOf(account);
    }

    function claim(address account, address recipient, uint256 maxAmount)
        external
        virtual
        nonReentrant
        returns (uint256)
    {
        if (account != _msgSender()) {
            revert("Vault: forbidden");
        }
        return withdrawalQueue().claim(account, recipient, maxAmount);
    }

    // symbiotic functions

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

    // helper functions

    function getBalances(address account)
        public
        view
        returns (
            uint256 accountAssets,
            uint256 accountInstantAssets,
            uint256 accountShares,
            uint256 accountInstantShares
        )
    {
        uint256 intantAssets = IERC20(asset()).balanceOf(address(this))
            + symbioticCollateral().balanceOf(address(this));
        accountShares = balanceOf(account);
        accountAssets = convertToAssets(accountShares);
        accountInstantAssets = accountAssets.min(intantAssets);
        accountInstantShares = convertToShares(accountInstantAssets);
    }
}
