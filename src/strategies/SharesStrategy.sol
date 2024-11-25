// // SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IDepositStrategy} from "../interfaces/strategies/IDepositStrategy.sol";
import {IRebalanceStrategy} from "../interfaces/strategies/IRebalanceStrategy.sol";
import {IWithdrawalStrategy} from "../interfaces/strategies/IWithdrawalStrategy.sol";
import {
    IDefaultCollateral, IERC20, IERC4626, IMultiVault
} from "../interfaces/vaults/IMultiVault.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract SharesStrategy is IDepositStrategy, IWithdrawalStrategy, IRebalanceStrategy {
    struct Ratio {
        uint64 minRatioD18;
        uint64 maxRatioD18;
    }

    uint256 public constant D18 = 1e18;
    bytes32 public constant SHARES_STRATEGY_SET_RATIO_ROLE =
        keccak256("SHARES_STRATEGY_SET_RATIO_ROLE");

    mapping(address vault => mapping(address subvault => Ratio)) private _ratios;

    function setRatio(address vault, address[] calldata subvaults, Ratio[] calldata ratios)
        external
    {
        require(
            IAccessControl(vault).hasRole(SHARES_STRATEGY_SET_RATIO_ROLE, msg.sender),
            "SharesStrategy: unauthorized"
        );
        require(
            subvaults.length == ratios.length,
            "SharesStrategy: subvaults and ratios length mismatch"
        );
        IMultiVault multiVault = IMultiVault(vault);
        uint256 n = subvaults.length;
        for (uint256 i = 0; i < n; i++) {
            if (multiVault.indexOfSubvault(subvaults[i]) != 0) {
                require(
                    ratios[i].minRatioD18 <= ratios[i].maxRatioD18 && ratios[i].maxRatioD18 <= D18,
                    "SharesStrategy: invalid ratios"
                );
            } else {
                require(
                    ratios[i].minRatioD18 == 0 && ratios[i].maxRatioD18 == 0,
                    "SharesStrategy: invalid subvault"
                );
            }
        }
        mapping(address => Ratio) storage ratios_ = _ratios[vault];
        for (uint256 i = 0; i < n; i++) {
            ratios_[subvaults[i]] = ratios[i];
        }
    }

    function calculateState(address vault)
        public
        view
        returns (uint256[] memory minAssets, uint256[] memory maxAssets, uint256[] memory assets)
    {
        IMultiVault multiVault = IMultiVault(vault);
        uint256 n = multiVault.subvaultsCount();
        minAssets = new uint256[](n);
        maxAssets = new uint256[](n);
        assets = new uint256[](n);

        uint256 totalAssets = IERC20(IERC4626(vault).asset()).balanceOf(vault);
        {
            IDefaultCollateral defaultCollateral = multiVault.symbioticDefaultCollateral();
            if (address(defaultCollateral) != address(0)) {
                totalAssets += IERC20(defaultCollateral.asset()).balanceOf(vault);
            }
            for (uint256 i = 0; i < n; i++) {
                (uint256 claimable, uint256 pending, uint256 staked) = multiVault.maxWithdraw(i);
                assets[i] = staked + pending + claimable;
                maxAssets[i] = assets[i] + multiVault.maxDeposit(i);
            }
        }
        {
            mapping(address => Ratio) storage ratios = _ratios[vault];
            for (uint256 i = 0; i < n; i++) {
                Ratio memory ratio = ratios[multiVault.subvaultAt(i).vault];
                if (ratio.maxRatioD18 == 0) {
                    continue;
                }
                minAssets[i] = (totalAssets * ratio.minRatioD18) / D18;
                maxAssets[i] = (totalAssets * ratio.maxRatioD18) / D18;
            }
        }
    }

    function calculateDepositAmounts(address vault, uint256 amount)
        external
        view
        override
        returns (DepositData[] memory subvaultsData)
    {
        IMultiVault multiVault = IMultiVault(vault);
        (uint256[] memory minAssets, uint256[] memory maxAssets, uint256[] memory assets) =
            calculateState(vault);

        uint256 n = multiVault.subvaultsCount();
        for (uint256 i = 0; i < n; i++) {
            uint256 assets_ = assets[i];
            if (minAssets[i] > assets_) {
                minAssets[i] -= assets_;
                maxAssets[i] -= assets_;
            } else if (maxAssets[i] > assets_) {
                minAssets[i] = 0;
                maxAssets[i] -= assets_;
            } else {
                minAssets[i] = 0;
                maxAssets[i] = 0;
            }
        }

        subvaultsData = new DepositData[](n);
        for (uint256 i = 0; i < n && amount != 0; i++) {
            subvaultsData[i].subvaultIndex = i;
            if (minAssets[i] == 0) {
                continue;
            }
            uint256 assets_ = Math.min(minAssets[i], amount);
            maxAssets[i] -= assets_;
            amount -= assets_;
            subvaultsData[i].depositAmount = assets_;
        }
        for (uint256 i = 0; i < n && amount != 0; i++) {
            if (maxAssets[i] == 0) {
                continue;
            }
            uint256 assets_ = Math.min(maxAssets[i], amount);
            amount -= assets_;
            subvaultsData[i].depositAmount += assets_;
        }
        uint256 count = 0;
        for (uint256 i = 0; i < n; i++) {
            if (subvaultsData[i].depositAmount != 0) {
                if (count != i) {
                    subvaultsData[count] = subvaultsData[i];
                }
                count++;
            }
        }
        assembly {
            mstore(subvaultsData, count)
        }
    }

    function calculateWithdrawalAmounts(address vault, uint256 amount)
        external
        view
        override
        returns (WithdrawalData[] memory subvaultsData)
    {
        IMultiVault multiVault = IMultiVault(vault);
        (uint256[] memory minAssets, uint256[] memory maxAssets, uint256[] memory assets) =
            calculateState(vault);
        uint256 n = multiVault.subvaultsCount();
        uint256[] memory maxWithdrawals = new uint256[](n * 3);
        subvaultsData = new WithdrawalData[](n);
        for (uint256 i = 0; i < n; i++) {
            (uint256 claimable, uint256 pending, uint256 staked) = multiVault.maxWithdraw(i);
            maxWithdrawals[i] = staked;
            maxWithdrawals[i + n] = pending;
            maxWithdrawals[i + 2 * n] = claimable;
            subvaultsData[i].subvaultIndex = i;
        }
        // extra amounts
        for (uint256 withdrawalType = 0; withdrawalType < 3 && amount != 0; withdrawalType++) {
            for (uint256 index = 0; index < n && amount != 0; index++) {
                uint256 withdrawalIndex = index + withdrawalType * n;
                if (maxWithdrawals[withdrawalIndex] == 0 || maxAssets[index] >= assets[index]) {
                    continue;
                }
                uint256 assets_ = Math.min(
                    amount,
                    Math.min(maxWithdrawals[withdrawalIndex], assets[index] - maxAssets[index])
                );
                if (withdrawalType == 0) {
                    subvaultsData[index].withdrawalRequestAmount += assets_;
                } else if (withdrawalType == 1) {
                    subvaultsData[index].withdrawalTransferPendingAmount += assets_;
                } else {
                    subvaultsData[index].claimAmount += assets_;
                }
                amount -= assets_;
                assets[index] -= assets_;
                maxWithdrawals[withdrawalIndex] -= assets_;
            }
        }

        // regular amounts
        for (uint256 withdrawalType = 0; withdrawalType < 3 && amount != 0; withdrawalType++) {
            for (uint256 index = 0; index < n && amount != 0; index++) {
                uint256 withdrawalIndex = index + withdrawalType * n;
                if (maxWithdrawals[withdrawalIndex] == 0 || minAssets[index] > assets[index]) {
                    continue;
                }
                uint256 assets_ = Math.min(
                    amount,
                    Math.min(maxWithdrawals[withdrawalIndex], assets[index] - minAssets[index])
                );
                if (withdrawalType == 0) {
                    subvaultsData[index].withdrawalRequestAmount += assets_;
                } else if (withdrawalType == 1) {
                    subvaultsData[index].withdrawalTransferPendingAmount += assets_;
                } else {
                    subvaultsData[index].claimAmount += assets_;
                }
                amount -= assets_;
                assets[index] -= assets_;
                maxWithdrawals[withdrawalIndex] -= assets_;
            }
        }

        // leftovers
        for (uint256 withdrawalType = 0; withdrawalType < 3 && amount != 0; withdrawalType++) {
            for (uint256 index = 0; index < n && amount != 0; index++) {
                uint256 withdrawalIndex = index + withdrawalType * n;
                if (maxWithdrawals[withdrawalIndex] == 0 || minAssets[index] == 0) {
                    continue;
                }
                uint256 assets_ =
                    Math.min(amount, Math.min(maxWithdrawals[withdrawalIndex], minAssets[index]));
                if (withdrawalType == 0) {
                    subvaultsData[index].withdrawalRequestAmount += assets_;
                } else if (withdrawalType == 1) {
                    subvaultsData[index].withdrawalTransferPendingAmount += assets_;
                } else {
                    subvaultsData[index].claimAmount += assets_;
                }
                amount -= assets_;
                assets[index] -= assets_;
                maxWithdrawals[withdrawalIndex] -= assets_;
            }
        }

        uint256 count = 0;
        for (uint256 i = 0; i < n; i++) {
            if (
                subvaultsData[i].withdrawalRequestAmount != 0
                    || subvaultsData[i].withdrawalTransferPendingAmount != 0
                    || subvaultsData[i].claimAmount != 0
            ) {
                if (count != i) {
                    subvaultsData[count] = subvaultsData[i];
                }
                count++;
            }
        }
        assembly {
            mstore(subvaultsData, count)
        }
    }

    function calculateRebalanceAmounts(address vault)
        external
        view
        override
        returns (RebalanceData[] memory subvaultsData)
    {
        IMultiVault multiVault = IMultiVault(vault);
        (uint256[] memory minAssets, uint256[] memory maxAssets, uint256[] memory assets) =
            calculateState(vault);
        uint256 n = multiVault.subvaultsCount();
        uint256[] memory maxWithdrawals = new uint256[](n);
        subvaultsData = new WithdrawalData[](n);
        uint256 requiredAmounts = 0;
        uint256 totalPending = 0;
        uint256 liquid = 0;
        for (uint256 i = 0; i < n; i++) {
            (uint256 claimable, uint256 pending, uint256 staked) = multiVault.maxWithdraw(i);
            maxWithdrawals[i] = staked;
            subvaultsData[i].subvaultIndex = i;
            subvaultsData[i].claimAmount = claimable;
            assets[i] -= claimable + pending;
            if (minAssets[i] > assets[i]) {
                requiredAmounts += minAssets[i] - assets[i];
            }
            totalPending += pending;
            liquid += claimable;
        }

        /*
            claim all claimable
            request all extra (assets - claimable - pending - maxAssets)
            request all required assets up to minAssets
        */

        {
            liquid += IERC20(IERC4626(vault).asset()).balanceOf(vault);
            IDefaultCollateral defaultCollateral = multiVault.symbioticDefaultCollateral();
            if (address(defaultCollateral) != address(0)) {
                liquid += IERC20(defaultCollateral.asset()).balanceOf(vault);
            }

            if (liquid > requiredAmounts) {
                requiredAmounts = 0;
            } else {
                requiredAmounts -= liquid;
            }
        }

        for (uint256 i = 0; i < n && requiredAmounts < totalPending; i++) {}
    }
}
