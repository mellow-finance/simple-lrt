// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./MultiVaultStorage.sol";

contract MultiVault is ERC4626Vault, MultiVaultStorage {
    using SafeERC20 for IERC20;
    using SafeERC20 for address;
    using Math for uint256;

    struct InitParams {
        address depositStrategy;
        address withdrawalStrategy;
        address rebalanceStrategy;
        address symbioticDefaultCollateral;
        address eigenLayerStrategyManager;
        address eigenLayerDelegationManager;
        address eigenLayerRewardsCoordinator;
    }

    // MUST be non-zero
    // and at least 1000 in case if we are expecting to have some number of EigenLayer strategies
    uint256 public immutable sharesOffset;
    uint256 public immutable assetsOffset;

    constructor(bytes32 name_, uint256 version_, uint256 sharesOffset_, uint256 assetsOffset_)
        VaultControlStorage(name_, version_)
        MultiVaultStorage(name_, version_)
    {
        if (sharesOffset_ == 0) {
            revert("MultiVault: sharesOffset is 0");
        }
        if (assetsOffset_ == 0) {
            revert("MultiVault: assetsOffset is 0");
        }
        sharesOffset = sharesOffset_;
        assetsOffset = assetsOffset_;
    }

    // ------------------------------- EXTERNAL FUNCTIONS -------------------------------

    function initialize(
        address _admin,
        uint256 _limit,
        bool _depositPause,
        bool _withdrawalPause,
        bool _depositWhitelist,
        address _asset,
        string memory _name,
        string memory _symbol,
        InitParams memory initParams
    ) public virtual initializer {
        __initializeERC4626(
            _admin,
            _limit,
            _depositPause,
            _withdrawalPause,
            _depositWhitelist,
            _asset,
            _name,
            _symbol
        );
        __initializeMultiVaultStorage(
            initParams.depositStrategy,
            initParams.withdrawalStrategy,
            initParams.rebalanceStrategy,
            initParams.symbioticDefaultCollateral,
            initParams.eigenLayerStrategyManager,
            initParams.eigenLayerDelegationManager,
            initParams.eigenLayerRewardsCoordinator
        );
    }

    function maxDeposit(uint256 subvaultIndex) public view returns (uint256) {
        Subvault memory subvault = subvaultAt(subvaultIndex);
        if (subvault.subvaultType == SubvaultType.SYMBIOTIC) {
            ISymbioticVault symbioticVault = ISymbioticVault(subvault.vault);
            if (!symbioticVault.isDepositLimit()) {
                return type(uint256).max;
            }
            uint256 stake = symbioticVault.activeStake();
            uint256 limit = symbioticVault.depositLimit();
            return limit <= stake ? 0 : limit - stake;
        } else if (subvault.subvaultType == SubvaultType.EIGEN_LAYER) {
            return type(uint256).max; // dont care for eigen layer strategy limits atm
        } else if (subvault.subvaultType == SubvaultType.ERC4626) {
            return IERC4626(subvault.vault).maxDeposit(address(this));
        } else {
            revert("MultiVault: unknown subvault type");
        }
    }

    function maxWithdraw(uint256 subvaultIndex)
        public
        view
        returns (uint256 claimable, uint256 pending, uint256 staked)
    {
        address this_ = address(this);
        Subvault memory subvault = subvaultAt(subvaultIndex);
        if (subvault.subvaultType == SubvaultType.SYMBIOTIC) {
            staked = ISymbioticVault(subvault.vault).activeBalanceOf(this_);
        } else if (subvault.subvaultType == SubvaultType.EIGEN_LAYER) {
            staked = IStrategy(subvault.vault).userUnderlyingView(this_);
        } else if (subvault.subvaultType == SubvaultType.ERC4626) {
            staked = IERC4626(subvault.vault).maxWithdraw(this_);
            return (0, 0, staked); // no claimable or pending for ERC4626
        }
        claimable = IWithdrawalQueue(subvault.withdrawalQueue).claimableAssetsOf(this_);
        pending = IWithdrawalQueue(subvault.withdrawalQueue).pendingAssetsOf(this_);
    }

    function totalAssets()
        public
        view
        virtual
        override(IERC4626, ERC4626Upgradeable)
        returns (uint256 assets_)
    {
        address this_ = address(this);
        assets_ = IERC20(asset()).balanceOf(this_);
        IDefaultCollateral collateral = symbioticDefaultCollateral();
        if (address(collateral) != address(0)) {
            assets_ += collateral.balanceOf(this_);
        }

        uint256 length = subvaultsCount();
        for (uint256 i = 0; i < length; i++) {
            (uint256 claimable, uint256 pending, uint256 staked) = maxWithdraw(i);
            assets_ += claimable + pending + staked;
        }
    }

    function addSubvault(address subvault, address withdrawalQueue, SubvaultType subvaultType)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _addSubvault(subvault, withdrawalQueue, subvaultType);
    }

    function removeSubvault(address subvault) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _removeSubvault(subvault);
    }

    function setDepositStrategy(address newDepositStrategy) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setDepositStrategy(newDepositStrategy);
    }

    function setWithdrawalStrategy(address newWithdrawalStrategy)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setWithdrawalStrategy(newWithdrawalStrategy);
    }

    function setRebalanceStrategy(address newRebalanceStrategy)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setRebalanceStrategy(newRebalanceStrategy);
    }

    function setSymbioticDefaultCollateral(address newSymbioticDefaultCollateral)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setSymbioticDefaultCollateral(newSymbioticDefaultCollateral);
    }

    function setEigenLayerStrategyManager(address newEigenLayerStrategyManager)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setEigenLayerStrategyManager(newEigenLayerStrategyManager);
    }

    function setEigenLayerDelegationManager(address newEigenLayerDelegationManager)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setEigenLayerDelegationManager(newEigenLayerDelegationManager);
    }

    function setEigenLayerRewardsCoordinator(address newEigenLayerRewardsCoordinator)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setEigenLayerRewardsCoordinator(newEigenLayerRewardsCoordinator);
    }

    // ------------------------------- INTERNAL FUNCTIONS -------------------------------

    function _deposit(uint256 subvaultIndex, uint256 assets) private {
        if (assets == 0) {
            return;
        }
        Subvault memory subvault = subvaultAt(subvaultIndex);
        address this_ = address(this);
        IERC20 asset_ = IERC20(asset());
        asset_.safeIncreaseAllowance(subvault.vault, assets);
        if (subvault.subvaultType == SubvaultType.SYMBIOTIC) {
            ISymbioticVault(subvault.vault).deposit(this_, assets);
        } else if (subvault.subvaultType == SubvaultType.EIGEN_LAYER) {
            IStrategyManager(eigenLayerStrategyManager()).depositIntoStrategy(
                IStrategy(subvault.vault), asset_, assets
            );
        } else if (subvault.subvaultType == SubvaultType.ERC4626) {
            IERC4626(subvault.vault).deposit(assets, this_);
        }
    }

    function _withdraw(
        uint256 subvaultIndex,
        uint256 request,
        uint256 pending,
        uint256 claimable,
        address owner,
        address receiver
    ) private {
        Subvault memory subvault = subvaultAt(subvaultIndex);
        address this_ = address(this);
        if (request != 0) {
            if (subvault.subvaultType == SubvaultType.SYMBIOTIC) {
                ISymbioticVault(subvault.vault).withdraw(this_, request);
                IWithdrawalQueue(subvault.withdrawalQueue).request(receiver, request);
            } else if (subvault.subvaultType == SubvaultType.EIGEN_LAYER) {
                IEigenLayerWithdrawalQueue(subvault.withdrawalQueue).request(
                    receiver, request, owner == receiver
                );
            } else if (subvault.subvaultType == SubvaultType.ERC4626) {
                IERC4626(subvault.vault).withdraw(request, this_, receiver);
            }
        }
        if (pending != 0) {
            IWithdrawalQueue(subvault.withdrawalQueue).transferPendingAssets(
                this_, receiver, pending
            );
        }
        if (claimable != 0) {
            IWithdrawalQueue(subvault.withdrawalQueue).claim(this_, receiver, claimable);
        }
    }

    function _depositIntoCollateral() private {
        IDefaultCollateral collateral = symbioticDefaultCollateral();
        if (address(collateral) == address(0)) {
            return;
        }
        uint256 limit_ = collateral.limit();
        uint256 supply_ = collateral.totalSupply();
        if (supply_ >= limit_) {
            return;
        }
        address this_ = address(this);
        IERC20 asset_ = IERC20(asset());
        uint256 amount = Math.min(limit_ - supply_, asset_.balanceOf(this_));
        if (amount == 0) {
            return;
        }
        asset_.safeIncreaseAllowance(address(collateral), amount);
        collateral.deposit(this_, amount);
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        virtual
        override
    {
        super._deposit(caller, receiver, assets, shares);
        address this_ = address(this);
        IBaseDepositStrategy.Data[] memory data =
            IBaseDepositStrategy(depositStrategy()).calculateDepositAmounts(this_, assets);
        for (uint256 i = 0; i < data.length; i++) {
            IBaseDepositStrategy.Data memory d = data[i];
            if (d.depositAmount == 0) {
                continue;
            }
            _deposit(d.subvaultIndex, d.depositAmount);
            assets -= d.depositAmount;
        }

        _depositIntoCollateral();
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        address this_ = address(this);

        IBaseWithdrawalStrategy.Data[] memory data =
            IBaseWithdrawalStrategy(withdrawalStrategy()).calculateWithdrawalAmounts(this_, assets);

        _burn(owner, shares);

        uint256 liquidAsset = assets;
        IBaseWithdrawalStrategy.Data memory d;
        for (uint256 i = 0; i < data.length; i++) {
            d = data[i];
            _withdraw(
                d.subvaultIndex,
                d.withdrawalRequestAmount,
                d.withdrawalTransferPendingAmount,
                d.claimAmount,
                owner,
                receiver
            );
            liquidAsset -=
                d.withdrawalRequestAmount + d.withdrawalTransferPendingAmount + d.claimAmount;
        }

        if (liquidAsset != 0) {
            IERC20 asset_ = IERC20(asset());
            uint256 assetBalance = asset_.balanceOf(this_);
            if (assetBalance != 0) {
                assetBalance = Math.min(assetBalance, liquidAsset);
                asset_.safeTransfer(receiver, assetBalance);
                liquidAsset -= assetBalance;
            }

            symbioticDefaultCollateral().withdraw(receiver, liquidAsset);
        }

        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        // emitting event with transfered + new pending assets
        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    function rebalance() external {
        address this_ = address(this);
        IBaseRebalanceStrategy.Data[] memory data =
            IBaseRebalanceStrategy(rebalanceStrategy()).calculateRebalaneAmounts(this_);
        IBaseRebalanceStrategy.Data memory d;
        uint256 depositAmount = 0;
        for (uint256 i = 0; i < data.length; i++) {
            d = data[i];
            _withdraw(d.subvaultIndex, d.withdrawalRequestAmount, 0, d.claimAmount, this_, this_);
            depositAmount += d.depositAmount;
        }
        uint256 assets_ = IERC20(asset()).balanceOf(this_);
        if (assets_ < depositAmount) {
            symbioticDefaultCollateral().withdraw(this_, depositAmount - assets_);
        }
        for (uint256 i = 0; i < data.length; i++) {
            d = data[i];
            _deposit(d.subvaultIndex, d.depositAmount);
        }
        _depositIntoCollateral();
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return assets.mulDiv(totalSupply() + sharesOffset, totalAssets() + assetsOffset, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return shares.mulDiv(totalAssets() + assetsOffset, totalSupply() + sharesOffset, rounding);
    }
}
