// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../MetaVault.sol";
import "../interfaces/strategies/IBaseWithdrawalStrategy.sol";

contract DefaultWithdrawalStrategy is IBaseWithdrawalStrategy {
    function calculateWithdrawalAmounts(address metaVault_, uint256 amount)
        external
        view
        override
        returns (Data[] memory subvaultsData)
    {
        MetaVault metaVault = MetaVault(metaVault_);
        uint256[] memory subvaults = metaVault.subvaults();
        subvaultsData = new Data[](subvaults.length);
        for (uint256 i = 0; i < subvaults.length; i++) {
            subvaultsData[i].subvaultIndex = i;
            uint256 assets = subvaults.maxWithdraw(metaVault_);
            if (assets == 0) {
                continue;
            }
            subvaultsData[i].withdrawRequestAmount = Math.min(assets, amount);
            amount -= subvaultsData[i].withdrawRequestAmount;
            if (amount == 0) {
                assembly {
                    mstore(subvaultsData, add(i, 1))
                }
                return data;
            }
        }
        for (uint256 i = 0; i < subvaults.length; i++) {
            uint256 pendingAssets = IQueuedVault(subvaults[i]).pendingAssetsOf(metaVault_);
            if (pendingAssets == 0) {
                continue;
            }
            subvaultsData[i].withdrawalTransferPendingAmount = Math.min(pendingAssets, amount);
            amount -= subvaultsData[i].withdrawalTransferPendingAmount;
            if (amount == 0) {
                assembly {
                    mstore(subvaultsData, add(i, 1))
                }
                return data;
            }
        }
        for (uint256 i = 0; i < subvaults.length; i++) {
            uint256 claimableAssets = IQueuedVault(subvaults[i]).claimableAssetsOf(metaVault_);
            if (claimableAssets == 0) {
                continue;
            }
            subvaultsData[i].claimAmount = Math.min(claimableAssets, amount);
            amount -= subvaultsData[i].claimAmount;
            if (amount == 0) {
                assembly {
                    mstore(subvaultsData, add(i, 1))
                }
                return data;
            }
        }
    }
}
