// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ERC4626Vault} from "./ERC4626Vault.sol";
import {MetaVaultStorage} from "./MetaVaultStorage.sol";
import {VaultControlStorage} from "./VaultControlStorage.sol";

import "./interfaces/vaults/IMetaVault.sol";

contract MetaVault is IMetaVault, ERC4626Vault, MetaVaultStorage {
    using SafeERC20 for IERC20;

    bytes32 private constant REBALANCE_ROLE = keccak256("REBALANCE_ROLE");
    bytes32 private constant SET_DEPOSIT_STRATEGY = keccak256("SET_DEPOSIT_STRATEGY");
    bytes32 private constant SET_WITHDRAWAL_STRATEGY = keccak256("SET_WITHDRAWAL_STRATEGY");
    bytes32 private constant SET_REBALANCE_STRATEGY = keccak256("SET_REBALANCE_STRATEGY");
    bytes32 private constant ADD_SUBVAULT = keccak256("ADD_SUBVAULT");
    bytes32 private constant REMOVE_SUBVAULT = keccak256("REMOVE_SUBVAULT");

    constructor(bytes32 name_, uint256 version_)
        MetaVaultStorage(name_, version_)
        VaultControlStorage(name_, version_)
    {}

    // ------------------------------- EXTERNAL FUNCTIONS -------------------------------

    /// @inheritdoc IMetaVault
    function initialize(InitParams memory initParams) public virtual initializer {
        __initialize(initParams);
    }

    /// @inheritdoc IMetaVault
    function rebalance() external onlyRole(REBALANCE_ROLE) {
        address asset_ = asset();
        address this_ = address(this);

        IBaseRebalanceStrategy.Data[] memory data =
            IBaseRebalanceStrategy(rebalanceStrategy()).calculateRebalaneAmounts(this_);
        for (uint256 i = 0; i < data.length; i++) {
            address subvault = subvaultAt(data[i].subvaultIndex);
            // claimable assets
            if (data[i].claimAmount != 0 && isQueuedVault(subvault)) {
                uint256 claimAmount = data[i].claimAmount;
                IQueuedVault(subvault).claim(this_, this_, claimAmount);
            }

            // withdrawal request
            if (data[i].withdrawalRequestAmount != 0) {
                uint256 withdrawalRequestAmount = data[i].withdrawalRequestAmount;
                IERC4626(subvault).withdraw(withdrawalRequestAmount, this_, this_);
            }
        }
        uint256 assets = IERC20(asset_).balanceOf(this_);
        for (uint256 i = 0; i < data.length; i++) {
            address subvault = subvaultAt(data[i].subvaultIndex);

            // deposit
            if (data[i].depositAmount != 0) {
                uint256 depositAmount = data[i].depositAmount;
                require(
                    depositAmount <= assets, "MetaVault: deposit amount exceeds available balance"
                );
                IERC20(asset_).safeIncreaseAllowance(address(subvault), depositAmount);
                IERC4626(subvault).deposit(depositAmount, this_);
                assets -= depositAmount;
            }
        }

        require(assets == 0, "MetaVault: non-zero asset balance after rebalance");

        emit Rebalance(msg.sender, block.timestamp, data);
    }

    /// @inheritdoc IMetaVault
    function setDepositStrategy(address newDepositStrategy)
        external
        onlyRole(SET_DEPOSIT_STRATEGY)
    {
        _setDepositStrategy(newDepositStrategy);
    }

    /// @inheritdoc IMetaVault
    function setWithdrawalStrategy(address newWithdrawalStrategy)
        external
        onlyRole(SET_WITHDRAWAL_STRATEGY)
    {
        _setWithdrawalStrategy(newWithdrawalStrategy);
    }

    /// @inheritdoc IMetaVault
    function setRebalanceStrategy(address newRebalanceStrategy)
        external
        onlyRole(SET_REBALANCE_STRATEGY)
    {
        _setRebalanceStrategy(newRebalanceStrategy);
    }

    /// @inheritdoc IMetaVault
    function addSubvault(address subvault, bool isQueuedVault) external onlyRole(ADD_SUBVAULT) {
        _addSubvault(subvault, isQueuedVault);
    }

    /// @inheritdoc IMetaVault
    function removeSubvault(address subvault) external onlyRole(REMOVE_SUBVAULT) {
        _removeSubvault(subvault);
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address account)
        public
        view
        virtual
        override(IERC4626, ERC4626Vault)
        returns (uint256)
    {
        uint256 maxDeposit_ = ERC4626Vault.maxDeposit(account);
        if (maxDeposit_ == 0) {
            return 0;
        }
        uint256 subvaultsDepositLimit_ = 0;
        address this_ = address(this);
        address[] memory subvaults_ = subvaults();
        uint256 inf = type(uint256).max;
        for (uint256 i = 0; i < subvaults_.length && subvaultsDepositLimit_ < maxDeposit_; i++) {
            address subvault = subvaults_[i];
            uint256 subvaultDepositLimit_ = IERC4626(subvault).maxDeposit(this_);
            if (inf - subvaultDepositLimit_ <= subvaultsDepositLimit_) {
                return maxDeposit_;
            }
            subvaultsDepositLimit_ += subvaultDepositLimit_;
        }
        return Math.min(subvaultsDepositLimit_, maxDeposit_);
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(address account)
        public
        view
        virtual
        override(IERC4626, ERC4626Vault)
        returns (uint256)
    {
        uint256 maxWithdraw_ = ERC4626Vault.maxWithdraw(account);
        if (maxWithdraw_ == 0) {
            return 0;
        }
        uint256 subvaultsWithdrawLimit_ = 0;
        address this_ = address(this);
        address[] memory subvaults_ = subvaults();
        uint256 inf = type(uint256).max;
        for (uint256 i = 0; i < subvaults_.length && subvaultsWithdrawLimit_ < maxWithdraw_; i++) {
            address subvault = subvaults_[i];
            uint256 subvaultWithdrawLimit_ = IERC4626(subvault).maxWithdraw(this_);
            if (inf - subvaultWithdrawLimit_ <= subvaultsWithdrawLimit_) {
                return maxWithdraw_;
            }
            subvaultsWithdrawLimit_ += subvaultWithdrawLimit_;

            if (isQueuedVault(subvault)) {
                uint256 claimableAssets = IQueuedVault(subvault).claimableAssetsOf(this_);
                if (inf - claimableAssets <= subvaultWithdrawLimit_) {
                    return maxWithdraw_;
                }
                subvaultWithdrawLimit_ += claimableAssets;

                uint256 pendingAssets = IQueuedVault(subvault).pendingAssetsOf(this_);
                if (inf - pendingAssets <= subvaultWithdrawLimit_) {
                    return maxWithdraw_;
                }
                subvaultWithdrawLimit_ += pendingAssets;
            }
        }
        return Math.min(subvaultsWithdrawLimit_, maxWithdraw_);
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
        uint256 totalAssets_ = IERC20(asset()).balanceOf(this_);
        address[] memory subvaults = subvaults();
        for (uint256 i = 0; i < subvaults.length; i++) {
            address subvault = subvaults[i];
            totalAssets_ += IERC4626(subvault).maxWithdraw(this_);
            if (isQueuedVault(subvault)) {
                totalAssets_ += IQueuedVault(subvault).pendingAssetsOf(this_)
                    + IQueuedVault(subvault).claimableAssetsOf(this_);
            }
        }
        return totalAssets_;
    }

    /// ------------------------------- INTERNAL FUNCTIONS -------------------------------

    function __initialize(InitParams memory initParams) internal virtual onlyInitializing {
        __initializeMetaVaultStorage(
            initParams.depositStrategy,
            initParams.withdrawalStrategy,
            initParams.rebalanceStrategy,
            initParams.idleVault
        );
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
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        virtual
        override
    {
        super._deposit(caller, receiver, assets, shares);

        address asset_ = asset();
        address this_ = address(this);

        IBaseDepositStrategy.Data[] memory data =
            IBaseDepositStrategy(depositStrategy()).calculateDepositAmounts(this_, assets);

        for (uint256 i = 0; i < data.length; i++) {
            address subvault = subvaultAt(data[i].subvaultIndex);
            uint256 assets_ = data[i].depositAmount;
            if (assets_ == 0) {
                continue;
            }
            require(assets >= assets_, "MetaVault: deposit amount exceeds available balance");
            IERC20(asset_).safeIncreaseAllowance(address(subvault), assets_);
            IERC4626(subvault).deposit(assets_, this_);
            assets -= assets_;
        }
        require(assets == 0, "MetaVault: deposited assets are not fully distributed");
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }
        _burn(owner, shares);

        address this_ = address(this);
        IBaseWithdrawalStrategy.Data[] memory data =
            IBaseWithdrawalStrategy(withdrawalStrategy()).calculateWithdrawalAmounts(this_, assets);

        for (uint256 i = 0; i < data.length; i++) {
            address subvault = subvaultAt(data[i].subvaultIndex);

            // regular withdrawal
            if (data[i].withdrawalRequestAmount != 0) {
                uint256 withdrawalRequestAmount = data[i].withdrawalRequestAmount;
                IERC4626(subvault).withdraw(withdrawalRequestAmount, receiver, this_);
                require(
                    withdrawalRequestAmount <= assets,
                    "MetaVault: withdrawal request amount exceeds available balance"
                );
                assets -= withdrawalRequestAmount;
            }

            if (!isQueuedVault(subvault)) {
                continue;
            }

            // withdrawal of claimable assets
            if (data[i].claimAmount != 0) {
                uint256 claimAmount = data[i].claimAmount;
                claimAmount = IQueuedVault(subvault).claim(this_, receiver, claimAmount);
                require(claimAmount <= assets, "MetaVault: claim amount exceeds available balance");
                assets -= claimAmount;
            }

            // withdrawal of pending due to rebalance logic assets
            if (data[i].withdrawalTransferPendingAmount != 0) {
                uint256 withdrawalTransferPendingAmount = data[i].withdrawalTransferPendingAmount;
                IQueuedVault(subvault).transferPendingAssets(
                    this_, receiver, withdrawalTransferPendingAmount
                );
                require(
                    withdrawalTransferPendingAmount <= assets,
                    "MetaVault: withdrawal transfer pending amount exceeds available balance"
                );
                assets -= withdrawalTransferPendingAmount;
            }
        }

        if (assets != 0) {
            revert("MetaVault: wrong withdrawal amount");
        }
        emit Withdraw(caller, receiver, owner, assets, shares);
    }
}
