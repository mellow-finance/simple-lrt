// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/math/Math.sol";

import "../MultiVault.sol";
import "../interfaces/strategies/IBaseDepositStrategy.sol";

contract MultiDepositStrategy is IBaseDepositStrategy {
    function calculateDepositAmounts(address multiVault_, uint256 amount)
        external
        view
        override
        returns (Data[] memory data)
    {
        MultiVault multiVault = MultiVault(multiVault_);
        uint256 length = multiVault.subvaultsCount();
        data = new Data[](length);
        uint256 index = 0;
        for (uint256 i = 0; i < length; i++) {
            uint256 maxDeposit = multiVault.maxDeposit(i);
            if (maxDeposit == 0) {
                continue;
            }
            uint256 asset = Math.min(maxDeposit, amount);
            amount -= asset;
            data[index++] = Data(i, asset);
            if (amount == 0) {
                assembly {
                    mstore(data, index)
                }
                break;
            }
        }
        if (index == 0) {
            return new Data[](0);
        }
    }
}
