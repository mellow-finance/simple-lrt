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

contract RatiosStrategy is IDepositStrategy, IWithdrawalStrategy, IRebalanceStrategy {
    struct Ratio {
        uint64 minRatioD18;
        uint64 maxRatioD18;
    }

    struct Amounts {
        uint256 min;
        uint256 max;
        uint256 claimable;
        uint256 pending;
        uint256 staked;
    }

    uint256 public constant D18 = 1e18;
    bytes32 public constant SHARES_STRATEGY_SET_RATIO_ROLE =
        keccak256("SHARES_STRATEGY_SET_RATIO_ROLE");

    mapping(address vault => mapping(address subvault => Ratio)) private _ratios;

    function getRatios(address vault, address subvault)
        external
        view
        returns (uint256 minRatioD18, uint256 maxRatioD18)
    {
        Ratio memory ratio = _ratios[vault][subvault];
        return (ratio.minRatioD18, ratio.maxRatioD18);
    }

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
        returns (Amounts[] memory state, uint256 liquid)
    {
        IMultiVault multiVault = IMultiVault(vault);
        uint256 n = multiVault.subvaultsCount();
        state = new Amounts[](n);

        liquid = IERC20(IERC4626(vault).asset()).balanceOf(vault);
        IDefaultCollateral defaultCollateral = multiVault.symbioticDefaultCollateral();
        if (address(defaultCollateral) != address(0)) {
            liquid += IERC20(defaultCollateral.asset()).balanceOf(vault);
        }
        uint256 totalAssets = liquid;
        for (uint256 i = 0; i < n; i++) {
            (state[i].claimable, state[i].pending, state[i].staked) = multiVault.maxWithdraw(i);
            uint256 assets = state[i].staked + state[i].pending + state[i].claimable;
            totalAssets += assets;
            state[i].max = assets + multiVault.maxDeposit(i);
        }
        mapping(address => Ratio) storage ratios = _ratios[vault];
        for (uint256 i = 0; i < n; i++) {
            Ratio memory ratio = ratios[multiVault.subvaultAt(i).vault];
            if (ratio.maxRatioD18 == 0) {
                continue;
            }
            state[i].max = Math.min(state[i].max, (totalAssets * ratio.maxRatioD18) / D18);
            state[i].min = Math.min(state[i].max, (totalAssets * ratio.minRatioD18) / D18);
        }
    }

    function calculateDepositAmounts(address vault, uint256 amount)
        external
        view
        override
        returns (DepositData[] memory subvaultsData)
    {
        (Amounts[] memory state, uint256 liquid) = calculateState(vault);
        amount += liquid;
        uint256 n = state.length;
        for (uint256 i = 0; i < n; i++) {
            uint256 assets_ = state[i].staked;
            if (state[i].min > assets_) {
                state[i].min -= assets_;
                state[i].max -= assets_;
            } else if (state[i].max > assets_) {
                state[i].min = 0;
                state[i].max -= assets_;
            } else {
                state[i].min = 0;
                state[i].max = 0;
            }
        }
        subvaultsData = new DepositData[](n);
        for (uint256 i = 0; i < n && amount != 0; i++) {
            subvaultsData[i].subvaultIndex = i;
            if (state[i].min == 0) {
                continue;
            }
            uint256 assets_ = Math.min(state[i].min, amount);
            state[i].max -= assets_;
            amount -= assets_;
            subvaultsData[i].depositAmount = assets_;
        }
        for (uint256 i = 0; i < n && amount != 0; i++) {
            if (state[i].max == 0) {
                continue;
            }
            uint256 assets_ = Math.min(state[i].max, amount);
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
        (Amounts[] memory state, uint256 liquid) = calculateState(vault);
        if (amount <= liquid) {
            return subvaultsData;
        }
        amount -= liquid;
        uint256 n = state.length;
        subvaultsData = new WithdrawalData[](n);
        for (uint256 i = 0; i < n && amount != 0; i++) {
            subvaultsData[i].subvaultIndex = i;
            if (state[i].staked > state[i].max) {
                uint256 extra = state[i].staked - state[i].max;
                if (extra > amount) {
                    subvaultsData[i].withdrawalRequestAmount = amount;
                    amount = 0;
                } else {
                    subvaultsData[i].withdrawalRequestAmount = extra;
                    amount -= extra;
                }
            }
        }
        for (uint256 i = 0; i < n && amount != 0; i++) {
            if (state[i].staked > state[i].min) {
                uint256 allowed = state[i].staked - state[i].min;
                if (allowed > amount) {
                    subvaultsData[i].withdrawalRequestAmount += amount;
                    amount = 0;
                } else {
                    subvaultsData[i].withdrawalRequestAmount += allowed;
                    amount -= allowed;
                }
            }
        }
        for (uint256 i = 0; i < n && amount != 0; i++) {
            if (state[i].pending > 0) {
                if (state[i].pending > amount) {
                    subvaultsData[i].withdrawalTransferPendingAmount += amount;
                    amount = 0;
                } else {
                    subvaultsData[i].withdrawalTransferPendingAmount += state[i].pending;
                    amount -= state[i].pending;
                }
            }
        }
        for (uint256 i = 0; i < n && amount != 0; i++) {
            if (state[i].claimable > 0) {
                if (state[i].claimable > amount) {
                    subvaultsData[i].claimAmount += amount;
                    amount = 0;
                } else {
                    subvaultsData[i].claimAmount += state[i].claimable;
                    amount -= state[i].claimable;
                }
            }
        }
        uint256 count = 0;
        for (uint256 i = 0; i < n; i++) {
            if (
                subvaultsData[i].withdrawalRequestAmount
                    + subvaultsData[i].withdrawalTransferPendingAmount + subvaultsData[i].claimAmount
                    != 0
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
        (Amounts[] memory state, uint256 liquid) = calculateState(vault);
        uint256 n = state.length;
        subvaultsData = new RebalanceData[](n);
        uint256 totalRequired = 0;
        uint256 totalPending = 0;
        for (uint256 i = 0; i < n; i++) {
            subvaultsData[i].subvaultIndex = i;
            subvaultsData[i].claimAmount = state[i].claimable;
            liquid += state[i].claimable;
            totalPending += state[i].pending;
            if (state[i].staked > state[i].max) {
                subvaultsData[i].withdrawalRequestAmount = state[i].staked - state[i].max;
                totalPending += subvaultsData[i].withdrawalRequestAmount;
                state[i].staked = state[i].max;
            }
            if (state[i].min > state[i].staked) {
                totalRequired += state[i].min - state[i].staked;
            }
        }

        if (totalRequired > liquid + totalPending) {
            uint256 amountForUnstake = totalRequired - liquid - totalPending;
            for (uint256 i = 0; i < n && amountForUnstake > 0; i++) {
                if (state[i].staked > state[i].min) {
                    uint256 allowed = state[i].staked - state[i].min;
                    if (allowed > amountForUnstake) {
                        subvaultsData[i].withdrawalRequestAmount += amountForUnstake;
                        amountForUnstake = 0;
                    } else {
                        subvaultsData[i].withdrawalRequestAmount += allowed;
                        amountForUnstake -= allowed;
                    }
                }
            }
        }

        for (uint256 i = 0; i < n && liquid > 0; i++) {
            if (state[i].staked < state[i].min) {
                uint256 required = state[i].min - state[i].staked;
                if (required > liquid) {
                    subvaultsData[i].depositAmount = liquid;
                    liquid = 0;
                } else {
                    subvaultsData[i].depositAmount = required;
                    liquid -= required;
                }
            }
        }

        for (uint256 i = 0; i < n && liquid > 0; i++) {
            if (state[i].staked < state[i].max) {
                uint256 allowed = state[i].max - state[i].staked;
                if (allowed > liquid) {
                    subvaultsData[i].depositAmount += liquid;
                    liquid = 0;
                } else {
                    subvaultsData[i].depositAmount += allowed;
                    liquid -= allowed;
                }
            }
        }
    }
}
