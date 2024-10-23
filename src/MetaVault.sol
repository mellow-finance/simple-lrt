// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ERC4626Vault} from "./ERC4626Vault.sol";

import "./MetaVaultStorage.sol";
import {VaultControlStorage} from "./VaultControlStorage.sol";
import "./interfaces/vaults/IMetaVault.sol";

contract MetaVault is IMetaVault, ERC4626Vault, MetaVaultStorage {
    using SafeERC20 for IERC20;

    bytes32 public constant REBALANCE_ROLE = keccak256("REBALANCE_ROLE");

    constructor(bytes32 name_, uint256 version_)
        MetaVaultStorage(name_, version_)
        VaultControlStorage(name_, version_)
    {}

    function initialize(InitParams memory initParams) public virtual initializer {
        __initialize(initParams);
    }

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

        IBaseDepositStrategy.Data[] memory data =
            IBaseDepositStrategy(depositStrategy()).calculateDepositAmounts(address(this), assets);

        address asset_ = asset();
        address this_ = address(this);

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
        IBaseWithdrawalStrategy.Data[] memory data = IBaseWithdrawalStrategy(withdrawalStrategy())
            .calculateWithdrawalAmounts(address(this), assets);

        address asset_ = asset();
        address this_ = address(this);
        for (uint256 i = 0; i < data.length; i++) {
            address subvault = subvaultAt(data[i].subvaultIndex);
            // withdrawal of claimable assets

            if (data[i].claimAmount != 0) {
                uint256 claimAmount = data[i].claimAmount;
                require(claimAmount <= assets, "MetaVault: claim amount exceeds available balance");
                claimAmount = IQueuedVault(subvault).claim(this_, receiver, claimAmount);
                assets -= claimAmount;
            }

            // withdrawal of pending due to rebalance logic assets
            if (data[i].withdrawalTransferPendingAmount != 0) {
                uint256 withdrawalTransferPendingAmount = data[i].withdrawalTransferPendingAmount;
                require(
                    withdrawalTransferPendingAmount <= assets,
                    "MetaVault: withdrawal transfer pending amount exceeds available balance"
                );
                // or direct call to the subvault?
                IWithdrawalQueue withdrawalQueue = IQueuedVault(subvault).withdrawalQueue();
                withdrawalQueue.transferPendingAssets(
                    this_, receiver, withdrawalTransferPendingAmount
                );
                assets -= withdrawalTransferPendingAmount;
            }

            // regular withdrawal
            if (data[i].withdrawalRequestAmount != 0) {
                uint256 withdrawalRequestAmount = data[i].withdrawalRequestAmount;
                require(
                    withdrawalRequestAmount <= assets,
                    "MetaVault: withdrawal request amount exceeds available balance"
                );
                IERC4626(subvault).withdraw(withdrawalRequestAmount, receiver, this_);
                assets -= withdrawalRequestAmount;
            }
        }

        if (assets != 0) {
            revert("MetaVault: wrong withdrawal amount");
        }
    }

    function rebalance() external onlyRole(REBALANCE_ROLE) {
        IBaseRebalanceStrategy.Data[] memory data =
            IBaseRebalanceStrategy(rebalanceStrategy()).calculateRebalaneAmounts(address(this));

        address asset_ = asset();
        address this_ = address(this);
        for (uint256 i = 0; i < data.length; i++) {
            address subvault = subvaultAt(data[i].subvaultIndex);

            // claimable assets
            if (data[i].claimAmount != 0) {
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
    }
}
