// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/tokens/IWSTETH.sol";
import "./IsolatedEigenLayerVault.sol";

contract IsolatedEigenLayerWstETHVault is IsolatedEigenLayerVault {
    using SafeERC20 for IERC20;

    IWSTETH public immutable wsteth;
    ISTETH public immutable steth;

    constructor(address vault_, address wsteth_) IsolatedEigenLayerVault(vault_) {
        wsteth = IWSTETH(wsteth_);
        steth = wsteth.stETH();
        require(wsteth_ == IERC4626(vault_).asset(), "Invalid asset");
    }

    function deposit(address manager, address strategy, uint256 assets)
        external
        override
        onlyVault
    {
        // insignificant amount
        if (assets <= 1) {
            return;
        }
        IERC20(wsteth).safeTransferFrom(vault, address(this), assets);
        assets = wsteth.unwrap(assets);
        IERC20(steth).safeIncreaseAllowance(manager, assets);
        IStrategyManager(manager).depositIntoStrategy(IStrategy(strategy), steth, assets);
    }

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

    function claimWithdrawal(
        IDelegationManager manager,
        IDelegationManager.Withdrawal calldata data
    ) external override returns (uint256 assets) {
        address this_ = address(this);
        (,,, address queue) = IIsolatedEigenLayerVaultFactory(factory).instances(this_);
        require(msg.sender == queue, "Only queue");
        IERC20 asset_ = IERC20(asset);
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = asset_;
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
