// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/strategies/IBaseRebalanceStrategy.sol";

contract DefaultRebalanceStrategy is IBaseRebalanceStrategy {
    function calculateRebalaneAmounts(address /* metaVault_ */ )
        external
        pure
        override
        returns (Data[] memory data)
    {
        // no rebalance logic here
        return data;
    }
}
