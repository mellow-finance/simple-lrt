// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IMetaVaultStorage} from "../interfaces/vaults/IMetaVaultStorage.sol";
import {IQueuedVault} from "../interfaces/vaults/IQueuedVault.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import "../interfaces/strategies/IBaseWithdrawalStrategy.sol";

contract DefaultWithdrawalStrategy is IBaseWithdrawalStrategy {
    function calculateWithdrawalAmounts(address metaVault, uint256 amount)
        external
        view
        override
        returns (Data[] memory data)
    {
        address[] memory subvaults = IMetaVaultStorage(metaVault).subvaults();
        data = new Data[](subvaults.length);
        for (uint256 i = 0; i < subvaults.length; i++) {
            data[i].subvaultIndex = i;
            uint256 assets = IERC4626(subvaults[i]).maxWithdraw(metaVault);
            if (assets == 0) {
                continue;
            }
            data[i].withdrawalRequestAmount = Math.min(assets, amount);
            amount -= data[i].withdrawalRequestAmount;
            if (amount == 0) {
                assembly {
                    mstore(data, add(i, 1))
                }
                return data;
            }
        }
        for (uint256 i = 0; i < subvaults.length; i++) {
            uint256 pendingAssets = IQueuedVault(subvaults[i]).pendingAssetsOf(metaVault);
            if (pendingAssets == 0) {
                continue;
            }
            data[i].withdrawalTransferPendingAmount = Math.min(pendingAssets, amount);
            amount -= data[i].withdrawalTransferPendingAmount;
            if (amount == 0) {
                assembly {
                    mstore(data, add(i, 1))
                }
                return data;
            }
        }
        for (uint256 i = 0; i < subvaults.length; i++) {
            uint256 claimableAssets = IQueuedVault(subvaults[i]).claimableAssetsOf(metaVault);
            if (claimableAssets == 0) {
                continue;
            }
            data[i].claimAmount = Math.min(claimableAssets, amount);
            amount -= data[i].claimAmount;
            if (amount == 0) {
                assembly {
                    mstore(data, add(i, 1))
                }
                return data;
            }
        }
    }
}
