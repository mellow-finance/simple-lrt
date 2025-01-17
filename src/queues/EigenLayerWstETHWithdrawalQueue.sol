// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/tokens/ISTETH.sol";
import "../interfaces/tokens/IWSTETH.sol";
import "./EigenLayerWithdrawalQueue.sol";

contract EigenLayerWstETHWithdrawalQueue is EigenLayerWithdrawalQueue {
    using SafeERC20 for IERC20;

    IWSTETH public immutable wsteth;

    constructor(address claimer_, address delegation_, address wsteth_)
        EigenLayerWithdrawalQueue(claimer_, delegation_)
    {
        wsteth = IWSTETH(wsteth_);
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
}
