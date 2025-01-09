// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/tokens/IWSTETH.sol";
import "./IsolatedEigenLayerVault.sol";

contract IsolatedEigenLayerWstETHVault is IsolatedEigenLayerVault {
    using SafeERC20 for IERC20;

    IWSTETH public immutable wsteth;
    ISTETH public immutable steth;

    constructor(address vault_, address wsteth_) IsolatedEigenLayerVault(vault_) {
        require(wsteth_ == IERC4626(vault_).asset(), "IsolatedEigenLayerWstETHVault: invalid asset");
        wsteth = IWSTETH(wsteth_);
        steth = wsteth.stETH();
    }

    /// @inheritdoc IIsolatedEigenLayerVault
    function deposit(address manager, address strategy, uint256 assets)
        external
        override
        onlyVault
    {
        if (assets <= 1) {
            // insignificant amount
            return;
        }
        IERC20(wsteth).safeTransferFrom(vault, address(this), assets);
        assets = wsteth.unwrap(assets);
        IERC20(steth).safeIncreaseAllowance(manager, assets);
        IStrategyManager(manager).depositIntoStrategy(IStrategy(strategy), steth, assets);
    }

    /// @inheritdoc IIsolatedEigenLayerVault
    function withdraw(address queue, address reciever, uint256 request, bool flag)
        external
        override
        onlyVault
    {
        if (request <= 1) {
            // insignificant amount
            return;
        }
        IEigenLayerWithdrawalQueue(queue).request(reciever, wsteth.getStETHByWstETH(request), flag);
    }

    /// @inheritdoc IIsolatedEigenLayerVault
    function claimWithdrawal(
        IDelegationManager manager,
        IDelegationManager.Withdrawal calldata data
    ) external override returns (uint256 assets) {
        address this_ = address(this);
        (,,, address queue) = IIsolatedEigenLayerVaultFactory(factory).instances(this_);
        require(msg.sender == queue, "IsolatedEigenLayerWstETHVault: forbidden");
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(steth);
        manager.completeQueuedWithdrawal(data, tokens, 0, true);
        assets = steth.balanceOf(this_);
        if (assets == 0) {
            return 0;
        }
        IERC20(steth).safeIncreaseAllowance(address(wsteth), assets);
        assets = wsteth.wrap(assets);
        if (assets == 0) {
            return 0;
        }
        IERC20(wsteth).safeTransfer(queue, assets);
    }
}
