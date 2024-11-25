// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ERC4626Vault} from "./ERC4626Vault.sol";
import {MultiVaultStorage} from "./MultiVaultStorage.sol";
import {VaultControlStorage} from "./VaultControlStorage.sol";
import "./interfaces/vaults/IMultiVault.sol";

contract MultiVault is IMultiVault, ERC4626Vault, MultiVaultStorage {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 private constant D6 = 1e6;

    constructor(bytes32 name_, uint256 version_)
        VaultControlStorage(name_, version_)
        MultiVaultStorage(name_, version_)
    {}

    // ------------------------------- EXTERNAL FUNCTIONS -------------------------------

    /// @inheritdoc IMultiVault
    function initialize(InitParams calldata initParams) public virtual initializer {
        __initializeERC4626(
            initParams.admin,
            initParams.limit,
            initParams.depositPause,
            initParams.withdrawalPause,
            initParams.depositWhitelist,
            initParams.asset,
            initParams.name,
            initParams.symbol
        );
        __initializeMultiVaultStorage(
            initParams.depositStrategy,
            initParams.withdrawalStrategy,
            initParams.rebalanceStrategy,
            initParams.symbioticDefaultCollateral,
            initParams.eigenLayerStrategyManager,
            initParams.eigenLayerRewardsCoordinator
        );
    }

    /// @inheritdoc IMultiVault
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

    /// @inheritdoc IMultiVault
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

    /// @inheritdoc IERC4626
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

    /// @inheritdoc IMultiVault
    function addSubvault(address vault, address withdrawalQueue, SubvaultType subvaultType)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        address asset_;
        if (subvaultType == SubvaultType.SYMBIOTIC) {
            asset_ = ISymbioticVault(vault).collateral();
        } else if (subvaultType == SubvaultType.EIGEN_LAYER) {
            if (
                IStrategyManager(eigenLayerStrategyManager()).strategyIsWhitelistedForDeposit(
                    IStrategy(vault)
                )
            ) {
                revert("MultiVault: strategy is not registered in the strategy manager");
            }
            asset_ = address(IStrategy(vault).underlyingToken());
        } else if (subvaultType == SubvaultType.ERC4626) {
            asset_ = IERC4626(vault).asset();
        }
        require(asset_ == asset(), "MultiVault: subvault asset does not match the vault asset");
        bool hasWithdrawalQueue = withdrawalQueue != address(0);
        bool isQueuedVault = subvaultType != SubvaultType.ERC4626;
        require(
            hasWithdrawalQueue == isQueuedVault,
            "MultiVault: withdrawal queue required for symbiotic and eigen layer vaults only"
        );
        _addSubvault(vault, withdrawalQueue, subvaultType);
    }

    /// @inheritdoc IMultiVault
    function removeSubvault(address subvault) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _removeSubvault(subvault);
    }

    /// @inheritdoc IMultiVault
    function setDepositStrategy(address newDepositStrategy) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setDepositStrategy(newDepositStrategy);
    }

    /// @inheritdoc IMultiVault
    function setWithdrawalStrategy(address newWithdrawalStrategy)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setWithdrawalStrategy(newWithdrawalStrategy);
    }

    /// @inheritdoc IMultiVault
    function setRebalanceStrategy(address newRebalanceStrategy)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setRebalanceStrategy(newRebalanceStrategy);
    }

    /// @inheritdoc IMultiVault
    function setSymbioticDefaultCollateral(address newSymbioticDefaultCollateral)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setSymbioticDefaultCollateral(newSymbioticDefaultCollateral);
    }

    /// @inheritdoc IMultiVault
    function setEigenLayerStrategyManager(address newEigenLayerStrategyManager)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setEigenLayerStrategyManager(newEigenLayerStrategyManager);
    }

    /// @inheritdoc IMultiVault
    function setEigenLayerRewardsCoordinator(address newEigenLayerRewardsCoordinator)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setEigenLayerRewardsCoordinator(newEigenLayerRewardsCoordinator);
    }

    function addRewardsData(uint256 farmId, RewardData calldata rewardData)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(rewardData.curatorFeeD6 <= D6, "Vault: invalid curator fee");
        require(rewardData.token != address(0), "Vault: token address cannot be zero");
        require(
            rewardData.distributionFarm != address(0),
            "Vault: distribution farm address cannot be zero"
        );
        if (rewardData.curatorFeeD6 != 0) {
            require(
                rewardData.curatorTreasury != address(0),
                "Vault: curator treasury address cannot be zero"
            );
        }
        if (rewardData.subvaultType == SubvaultType.SYMBIOTIC) {
            require(rewardData.data.length == 20, "Vault: invalid symbiotic farm data length");
        } else if (rewardData.subvaultType == SubvaultType.EIGEN_LAYER) {
            require(rewardData.data.length == 0, "Vault: invalid eigen layer farm data length");
        } else {
            revert("Vault: invalid subvault type");
        }
        _setRewardData(farmId, rewardData);
    }

    function removeRewardsData(uint256 farmId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        RewardData memory emptyData;
        _setRewardData(farmId, emptyData);
    }

    /// @inheritdoc IMultiVault
    function rebalance() external {
        address this_ = address(this);
        IRebalanceStrategy.RebalanceData[] memory data =
            IRebalanceStrategy(rebalanceStrategy()).calculateRebalanceAmounts(this_);
        IRebalanceStrategy.RebalanceData memory d;
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

    /// @inheritdoc IMultiVault
    function pushRewards(uint256 farmId, bytes calldata farmData) external {
        IMultiVaultStorage.RewardData memory data = rewardData(farmId);
        if (data.token == address(0)) {
            revert("MultiVault: farm not found");
        }
        IERC20 rewardToken = IERC20(data.token);

        address this_ = address(this);
        uint256 rewardAmount = rewardToken.balanceOf(this_);

        if (data.subvaultType == SubvaultType.SYMBIOTIC) {
            address symbioticFarm = abi.decode(data.data, (address));
            bytes memory symbioticFarmData = abi.decode(farmData, (bytes));
            IStakerRewards(symbioticFarm).claimRewards(
                this_, address(rewardToken), symbioticFarmData
            );
        } else if (data.subvaultType == SubvaultType.EIGEN_LAYER) {
            IRewardsCoordinator.RewardsMerkleClaim memory eigenLayerFarmData =
                abi.decode(farmData, (IRewardsCoordinator.RewardsMerkleClaim));
            require(
                eigenLayerFarmData.tokenLeaves.length == 1
                    && address(eigenLayerFarmData.tokenLeaves[0].token) == address(rewardToken),
                "Vault: invalid claim"
            );
            IRewardsCoordinator(eigenLayerRewardsCoordinator()).processClaim(
                eigenLayerFarmData, this_
            );
        } else {
            revert("MultiVault: unknown subvault type");
        }

        rewardAmount = rewardToken.balanceOf(this_) - rewardAmount;
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
        // emit RewardsPushed(farmId, rewardAmount, curatorFee, block.timestamp);
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
        uint256 amount = asset_.balanceOf(this_).min(limit_ - supply_);
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
        IDepositStrategy.DepositData[] memory data =
            IDepositStrategy(depositStrategy()).calculateDepositAmounts(this_, assets);
        IDepositStrategy.DepositData memory d;
        for (uint256 i = 0; i < data.length; i++) {
            d = data[i];
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

        IWithdrawalStrategy.WithdrawalData[] memory data =
            IWithdrawalStrategy(withdrawalStrategy()).calculateWithdrawalAmounts(this_, assets);

        _burn(owner, shares);

        uint256 liquidAsset = assets;
        IWithdrawalStrategy.WithdrawalData memory d;
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
                assetBalance = assetBalance.min(liquidAsset);
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
}
