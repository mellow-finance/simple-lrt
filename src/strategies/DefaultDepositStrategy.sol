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
        returns (Data[] memory subvaultsData)
    {
        MetaVault metaVault = MetaVault(metaVault_);
        uint256 subvaultsCount = metaVault.subvaultsCount();
        subvaultsData = new Data[](subvaultsCount);
        for (uint256 i = 0; i < subvaultsCount; i++) {
            subvaultsData[i].subvaultIndex = i;
            uint256 maxDeposit =
                IERC4626Vault(metaVault.subvaultAt(i)).maxDeposit(address(metaVault));
            subvaultsData[i].depositAmount = Math.min(maxDeposit, amount);
            amount -= subvaultsData[i].depositAmount;
            if (amount == 0 && i + 1 < subvaultsCount) {
                assembly {
                    mstore(subvaultsData, add(i, 1))
                }
            }
        }
    }
}
