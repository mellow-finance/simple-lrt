// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/tokens/ISTETH.sol";
import "../interfaces/tokens/IWSTETH.sol";
import "./EigenLayerWithdrawalQueue.sol";

contract EigenLayerWstETHWithdrawalQueue is EigenLayerWithdrawalQueue {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
    using Math for uint256;

    IWSTETH public immutable wsteth;
    ISTETH public immutable steth;

    constructor(address claimer_, address delegation_, address wsteth_)
        EigenLayerWithdrawalQueue(claimer_, delegation_)
    {
        wsteth = IWSTETH(wsteth_);
        steth = wsteth.stETH();
        _disableInitializers();
    }

    /// @inheritdoc IEigenLayerWithdrawalQueue
    function initialize(address isolatedVault_, address strategy_, address operator_)
        public
        override
        initializer
    {
        require(
            IIsolatedEigenLayerVault(isolatedVault_).asset() == address(wsteth),
            "EigenLayerWstETHWithdrawalQueue: invalid asset"
        );
        __init_EigenLayerWithdrawalQueue(isolatedVault_, strategy_, operator_);
    }

    /// --------------- EXTERNAL VIEW FUNCTIONS ---------------

    /// @inheritdoc IWithdrawalQueue
    function pendingAssetsOf(address account) public view override returns (uint256 assets) {
        assets = super.pendingAssetsOf(account);
        if (assets != 0) {
            assets = wsteth.getWstETHByStETH(assets);
        }
    }

    /// @inheritdoc IWithdrawalQueue
    function claimableAssetsOf(address account) public view override returns (uint256 assets) {
        AccountData storage accountData_ = _accountData[account];
        uint256[] memory indices = accountData_.withdrawals.values();
        uint256 block_ = latestWithdrawableBlock();
        uint256 counter = 0;
        uint256 shares = 0;
        for (uint256 i = 0; i < indices.length; i++) {
            WithdrawalData storage withdrawal = _withdrawals[indices[i]];
            if (withdrawal.isClaimed) {
                uint256 totalShares = withdrawal.shares;
                uint256 accountShares = withdrawal.sharesOf[account];
                assets += totalShares == accountShares
                    ? withdrawal.assets
                    : withdrawal.assets.mulDiv(accountShares, totalShares);
            } else if (block_ >= withdrawal.data.startBlock && counter < MAX_CLAIMING_WITHDRAWALS) {
                counter++;
                shares += withdrawal.sharesOf[account];
            }
        }
        assets += accountData_.claimableAssets;
        assets += shares == 0
            ? 0
            : wsteth.getWstETHByStETH(IStrategy(strategy).sharesToUnderlyingView(shares));
    }

    /// --------------- EXTERNAL MUTABLE FUNCTIONS ---------------

    function request(address account, uint256 assets, bool isSelfRequested) public override {
        super.request(account, wsteth.getStETHByWstETH(assets), isSelfRequested);
    }

    /// @inheritdoc IWithdrawalQueue
    function transferPendingAssets(address to, uint256 amount) public override {
        super.transferPendingAssets(to, wsteth.getStETHByWstETH(amount));
    }

    /// --------------- INTERNAL MUTABLE FUNCTIONS ---------------

    function _transferClaimableAsPending(
        AccountData storage accountDataFrom,
        AccountData storage accountDataTo,
        uint256 assets
    ) internal override {
        assets = wsteth.getWstETHByStETH(assets);
        if (assets > accountDataFrom.claimableAssets) {
            revert("EigenLayerWstETHWithdrawalQueue: insufficient pending assets");
        } else {
            accountDataFrom.claimableAssets -= assets;
            accountDataTo.claimableAssets += assets;
        }
    }

    function _pull(WithdrawalData storage withdrawal, uint256 index) internal override {
        uint256 assets = IIsolatedEigenLayerVault(isolatedVault).claimWithdrawal(
            IDelegationManager(delegation), withdrawal.data
        );
        IERC20(steth).safeIncreaseAllowance(address(wsteth), assets);
        assets = wsteth.wrap(assets);
        withdrawal.assets = assets;
        withdrawal.isClaimed = true;
        emit Pull(index, assets);
    }
}
