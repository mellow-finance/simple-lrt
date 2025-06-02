// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/tokens/IWSTETH.sol";
import "./EigenLayerAdapter.sol";

contract EigenLayerWstETHAdapter is EigenLayerAdapter {
    using SafeERC20 for IERC20;

    IWSTETH public immutable wsteth;
    ISTETH public immutable steth;

    constructor(
        address factory_,
        address vault_,
        IStrategyManager strategyManager_,
        IRewardsCoordinator rewardsCoordinator_,
        address wsteth_
    ) EigenLayerAdapter(factory_, vault_, strategyManager_, rewardsCoordinator_) {
        wsteth = IWSTETH(wsteth_);
        steth = wsteth.stETH();
    }

    /// @inheritdoc IProtocolAdapter
    function maxDeposit(address isolatedVault) public view override returns (uint256 assets) {
        assets = _maxDeposit(isolatedVault, address(steth));
        if (assets > type(uint128).max) {
            return type(uint256).max;
        }
        return assets == 0 ? 0 : wsteth.getWstETHByStETH(assets);
    }

    /// @inheritdoc IProtocolAdapter
    function stakedAt(address isolatedVault) public view override returns (uint256 assets) {
        assets = super.stakedAt(isolatedVault);
        return assets == 0 ? 0 : wsteth.getWstETHByStETH(assets);
    }
}
