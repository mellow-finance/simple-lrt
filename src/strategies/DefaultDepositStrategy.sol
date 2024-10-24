// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/math/Math.sol";

import "../MetaVault.sol";
import "../interfaces/strategies/IBaseDepositStrategy.sol";

contract DefaultDepositStrategy is IBaseDepositStrategy {
    function calculateDepositAmounts(address metaVault_, uint256 amount)
        external
        view
        override
        returns (Data[] memory data)
    {
        MetaVault metaVault = MetaVault(metaVault_);
        uint256 subvaultsCount = metaVault.subvaultsCount();
        data = new Data[](subvaultsCount);
        for (uint256 i = 0; i < subvaultsCount; i++) {
            data[i].subvaultIndex = i;
            uint256 maxDeposit =
                IERC4626Vault(metaVault.subvaultAt(i)).maxDeposit(address(metaVault));
            data[i].depositAmount = Math.min(maxDeposit, amount);
            amount -= data[i].depositAmount;
            if (amount == 0) {
                assembly {
                    mstore(data, add(i, 1))
                }
                break;
            }
        }
    }
}
