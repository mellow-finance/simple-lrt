// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/tokens/ISTETH.sol";
import "../interfaces/tokens/IWSTETH.sol";
import "./EigenLayerWithdrawalQueue.sol";

contract EigenLayerWstETHWithdrawalQueue is EigenLayerWithdrawalQueue {
    using SafeERC20 for IERC20;

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
