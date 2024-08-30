// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {ERC4626Vault} from "./ERC4626Vault.sol";
import {MellowSymbioticVaultStorage} from "./MellowSymbioticVaultStorage.sol";
import {VaultControl, VaultControlStorage} from "./VaultControl.sol";
import "./interfaces/vaults/IMellowSymbioticVault.sol";

contract MellowSymbioticVault is
    IMellowSymbioticVault,
    MellowSymbioticVaultStorage,
    ERC4626Vault
{
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 private constant D6 = 1e6;
    bytes32 private constant SET_FARM_ROLE = keccak256("SET_FARM_ROLE");
    bytes32 private constant REMOVE_FARM_ROLE = keccak256("REMOVE_FARM_ROLE");

    constructor(bytes32 contractName_, uint256 contractVersion_)
        MellowSymbioticVaultStorage(contractName_, contractVersion_)
        VaultControlStorage(contractName_, contractVersion_)
    {}

    /// @inheritdoc IMellowSymbioticVault
    function initialize(InitParams memory initParams) public virtual initializer {
        __initialize(initParams);
    }

    function __initialize(InitParams memory initParams) internal virtual onlyInitializing {
        address collateral = ISymbioticVault(initParams.symbioticVault).collateral();
        __initializeMellowSymbioticVaultStorage(
            initParams.symbioticCollateral, initParams.symbioticVault, initParams.withdrawalQueue
        );
        __initializeERC4626(
            initParams.admin,
            initParams.limit,
            initParams.depositPause,
            initParams.withdrawalPause,
            initParams.depositWhitelist,
            collateral,
            initParams.name,
            initParams.symbol
        );
    }

    /// @inheritdoc IMellowSymbioticVault
    function setFarm(uint256 farmId, FarmData memory farmData) external onlyRole(SET_FARM_ROLE) {
        _setFarmChecks(farmId, farmData);
        _setFarm(farmId, farmData);
    }

    function _setFarmChecks(uint256, /* id */ FarmData memory farmData) internal virtual {
        require(
            farmData.rewardToken != address(this)
                && farmData.rewardToken != address(symbioticVault()),
            "Vault: forbidden reward token"
        );
        require(farmData.curatorFeeD6 <= D6, "Vault: invalid curator fee");
    }

    /// @inheritdoc IERC4626
    function totalAssets()
        public
        view
        virtual
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256)
    {
        address this_ = address(this);
        return IERC20(asset()).balanceOf(this_) + symbioticCollateral().balanceOf(this_)
            + symbioticVault().activeBalanceOf(this_);
    }

    /// @inheritdoc ERC4626Upgradeable
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        virtual
        override
    {
        super._deposit(caller, receiver, assets, shares);
        pushIntoSymbiotic();
    }

    /// @inheritdoc ERC4626Upgradeable
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        address this_ = address(this);

        uint256 liquidAsset = IERC20(asset()).balanceOf(this_);
        if (liquidAsset >= assets) {
            return super._withdraw(caller, receiver, owner, assets, shares);
        }

        uint256 liquidCollateral = symbioticCollateral().balanceOf(this_);
        if (liquidCollateral != 0) {
            uint256 amount = liquidCollateral.min(assets - liquidAsset);
            symbioticCollateral().withdraw(this_, amount);
            liquidAsset += amount;

            if (liquidAsset >= assets) {
                return super._withdraw(caller, receiver, owner, assets, shares);
            }
        }

        uint256 staked = assets - liquidAsset;
        IWithdrawalQueue withdrawalQueue_ = withdrawalQueue();
        (, uint256 requestedShares) = symbioticVault().withdraw(address(withdrawalQueue_), staked);
        withdrawalQueue_.request(receiver, requestedShares);

        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        _burn(owner, shares);
        if (liquidAsset != 0) {
            IERC20(asset()).safeTransfer(receiver, liquidAsset);
        }

        // emitting event with transfered + new pending assets
        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    /// @inheritdoc IMellowSymbioticVault
    function claimableAssetsOf(address account) external view returns (uint256 claimableAssets) {
        claimableAssets = withdrawalQueue().claimableAssetsOf(account);
    }

    /// @inheritdoc IMellowSymbioticVault
    function pendingAssetsOf(address account) external view returns (uint256 pendingAssets) {
        pendingAssets = withdrawalQueue().pendingAssetsOf(account);
    }

    /// @inheritdoc IMellowSymbioticVault
    function claim(address account, address recipient, uint256 maxAmount)
        external
        virtual
        nonReentrant
        returns (uint256)
    {
        require(account == _msgSender(), "Vault: forbidden");
        return withdrawalQueue().claim(account, recipient, maxAmount);
    }

    /**
     * @notice Calculates the remaining deposit capacity in the Symbiotic Vault.
     * @param vault The Symbiotic Vault to check.
     * @return The remaining deposit capacity in the vault. Returns 0 if the vault has a deposit whitelist and the current contract is not whitelisted.
     *
     * @dev If the vault has no deposit limit, the maximum possible value is returned.
     *      If the deposit limit is greater than the current total stake, the difference is returned.
     *      Otherwise, returns 0.
     */
    function _calculateSymbioticVaultLeftover(ISymbioticVault vault)
        internal
        view
        returns (uint256)
    {
        if (vault.depositWhitelist() && !vault.isDepositorWhitelisted(address(this))) {
            return 0;
        }
        if (!vault.isDepositLimit()) {
            return type(uint256).max;
        }
        uint256 totalStake = vault.totalStake();
        uint256 limit = vault.depositLimit();
        if (limit > totalStake) {
            return limit - totalStake;
        }
        return 0;
    }

    /**
     * @notice Calculates the amounts to be withdrawn from collateral, deposited into collateral, and deposited into the Symbiotic Vault.
     * @param asset_ The ERC20 asset being managed.
     * @param collateral The collateral contract associated with the vault.
     * @param symbioticVault The Symbiotic Vault where assets may be deposited.
     * @return collateralWithdrawal The amount to be withdrawn from the collateral.
     * @return collateralDeposit The amount to be deposited into the collateral.
     * @return vaultDeposit The amount to be deposited into the Symbiotic Vault.
     *
     * @dev This function considers the balance of assets and collateral, the remaining deposit capacity in the Symbiotic Vault, and the collateral's limits.
     *      If the Symbiotic Vault has remaining capacity, assets are prioritized for deposit there.
     *      Remaining assets are then considered for collateral deposit based on the collateral's limit.
     * @custom:effects At most one of the `collateralWithdrawal` and `collateralDeposit` parameters will be non-zero.
     */
    function _calculatePushAmounts(
        IERC20 asset_,
        IDefaultCollateral collateral,
        ISymbioticVault symbioticVault
    )
        internal
        view
        returns (uint256 collateralWithdrawal, uint256 collateralDeposit, uint256 vaultDeposit)
    {
        address this_ = address(this);
        uint256 assetAmount = asset_.balanceOf(this_);
        uint256 collateralAmount = collateral.balanceOf(this_);

        uint256 symbioticVaultLeftover = _calculateSymbioticVaultLeftover(symbioticVault);
        if (symbioticVaultLeftover != 0) {
            if (assetAmount < symbioticVaultLeftover && collateralAmount != 0) {
                collateralWithdrawal = collateralAmount.min(symbioticVaultLeftover - assetAmount);
                assetAmount += collateralWithdrawal;
            }
            if (assetAmount != 0) {
                vaultDeposit = assetAmount.min(symbioticVaultLeftover);
                assetAmount -= vaultDeposit;
            }
        }

        if (assetAmount != 0) {
            uint256 collateralLimit = collateral.limit();
            uint256 collateralStake = collateral.totalSupply();

            if (collateralLimit > collateralStake) {
                collateralDeposit = assetAmount.min(collateralLimit - collateralStake);
            }
        }
    }

    /// @inheritdoc IMellowSymbioticVault
    function pushIntoSymbiotic()
        public
        returns (uint256 collateralWithdrawal, uint256 collateralDeposit, uint256 vaultDeposit)
    {
        IERC20 asset_ = IERC20(asset());
        IDefaultCollateral collateral = symbioticCollateral();
        ISymbioticVault symbioticVault = symbioticVault();
        address this_ = address(this);

        (collateralWithdrawal, collateralDeposit, vaultDeposit) =
            _calculatePushAmounts(asset_, collateral, symbioticVault);

        if (collateralWithdrawal != 0) {
            collateral.withdraw(this_, collateralWithdrawal);
        }

        if (collateralDeposit != 0) {
            asset_.safeIncreaseAllowance(address(collateral), collateralDeposit);
            collateral.deposit(this_, collateralDeposit);
        }

        if (vaultDeposit != 0) {
            asset_.safeIncreaseAllowance(address(symbioticVault), vaultDeposit);
            symbioticVault.deposit(this_, vaultDeposit);
        }

        emit SymbioticPushed(_msgSender(), collateralWithdrawal, collateralDeposit, vaultDeposit);
    }

    /// @inheritdoc IMellowSymbioticVault
    function pushRewards(uint256 farmId, bytes calldata symbioticRewardsData)
        external
        nonReentrant
    {
        FarmData memory data = symbioticFarm(farmId);
        require(data.rewardToken != address(0), "Vault: farm not set");
        IERC20 rewardToken = IERC20(data.rewardToken);
        uint256 amountBefore = rewardToken.balanceOf(address(this));
        IStakerRewards(data.symbioticFarm).claimRewards(
            address(this), address(rewardToken), symbioticRewardsData
        );
        uint256 rewardAmount = rewardToken.balanceOf(address(this)) - amountBefore;
        if (rewardAmount == 0) {
            return;
        }

        uint256 curatorFee = rewardAmount.mulDiv(data.curatorFeeD6, D6);
        if (curatorFee != 0) {
            rewardToken.safeTransfer(data.curatorTreasury, curatorFee);
        }
        // Guranteed to be >= 0 since data.curatorFeeD6 <= D6
        rewardAmount = rewardAmount - curatorFee;
        if (rewardAmount != 0) {
            rewardToken.safeTransfer(data.distributionFarm, rewardAmount);
        }
        emit RewardsPushed(farmId, rewardAmount, curatorFee, block.timestamp);
    }

    /// @inheritdoc IMellowSymbioticVault
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
        address this_ = address(this);
        uint256 instantAssets =
            IERC20(asset()).balanceOf(this_) + symbioticCollateral().balanceOf(this_);
        accountShares = balanceOf(account);
        accountAssets = convertToAssets(accountShares);
        accountInstantAssets = accountAssets.min(instantAssets);
        accountInstantShares = convertToShares(accountInstantAssets);
    }
}
