// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../MultiVault.sol";
import {IMetaVaultStorage} from "../interfaces/vaults/IMetaVaultStorage.sol";
import {IQueuedVault} from "../interfaces/vaults/IQueuedVault.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import "../interfaces/strategies/IBaseWithdrawalStrategy.sol";

contract MultiWithdrawalStrategy is IBaseWithdrawalStrategy {
    function calculateWithdrawalAmounts(address multiVault_, uint256 amount)
        external
        view
        override
        returns (Data[] memory data)
    {
        MultiVault multiVault = MultiVault(multiVault_);
        uint256 length = multiVault.subvaultsCount();

        uint256 defaultCollateralBalance =
            IERC20(multiVault.symbioticDefaultCollateral()).balanceOf(multiVault_);
        uint256 assetBalance = IERC20(multiVault.asset()).balanceOf(multiVault_);

        if (assetBalance + defaultCollateralBalance >= amount) {
            return new Data[](0);
        }
        amount -= assetBalance + defaultCollateralBalance;

        uint256 index = 0;
        data = new Data[](length);
        for (uint256 i = 0; i < length; i++) {
            (uint256 claimable, uint256 pending, uint256 staked) = multiVault.maxWithdraw(i);
            if (staked + pending + claimable == 0) {
                continue;
            }
            staked = Math.min(staked, amount);
            amount -= staked;

            pending = Math.min(pending, amount);
            amount -= pending;

            claimable = Math.min(claimable, amount);
            amount -= claimable;

            data[index++] = Data({
                subvaultIndex: i,
                withdrawalRequestAmount: staked,
                withdrawalTransferPendingAmount: pending,
                claimAmount: claimable
            });
            if (amount == 0) {
                assembly {
                    mstore(data, add(i, 1))
                }
                return data;
            }
        }
    }
}
