// // SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/strategies/IRatiosStrategy.sol";

contract RatiosStrategy is IRatiosStrategy {
    uint256 public constant D18 = 1e18;
    bytes32 public constant SHARES_STRATEGY_SET_RATIO_ROLE =
        keccak256("SHARES_STRATEGY_SET_RATIO_ROLE");

    mapping(address vault => mapping(address subvault => Ratio)) private _ratios;

    /// @inheritdoc IRatiosStrategy
    function getRatios(address vault, address subvault)
        external
        view
        returns (uint256 minRatioD18, uint256 maxRatioD18)
    {
        Ratio memory ratio = _ratios[vault][subvault];
        return (ratio.minRatioD18, ratio.maxRatioD18);
    }

    /// @inheritdoc IRatiosStrategy
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

    /// @inheritdoc IRatiosStrategy
    function calculateState(address vault, bool isDeposit, uint256 increment)
        public
        view
        returns (Amounts[] memory state, uint256 liquid)
    {
        IMultiVault multiVault = IMultiVault(vault);
        uint256 n = multiVault.subvaultsCount();
        state = new Amounts[](n);

        liquid = IERC20(IERC4626(vault).asset()).balanceOf(vault);
        IDefaultCollateral collateral = multiVault.defaultCollateral();
        if (address(collateral) != address(0)) {
            liquid += collateral.balanceOf(vault);
        }
        uint256 totalAssets = liquid;
        for (uint256 i = 0; i < n; i++) {
            (state[i].claimable, state[i].pending, state[i].staked) = multiVault.assetsOf(i);
            uint256 assets = state[i].staked + state[i].pending + state[i].claimable;
            totalAssets += assets;
            uint256 maxDeposit = multiVault.maxDeposit(i);
            if (type(uint256).max - assets > maxDeposit) {
                state[i].max = maxDeposit + assets;
            } else {
                state[i].max = type(uint256).max;
            }
        }
        totalAssets = isDeposit ? totalAssets + increment : totalAssets - increment;
        mapping(address => Ratio) storage ratios = _ratios[vault];
        for (uint256 i = 0; i < n; i++) {
            Ratio memory ratio = ratios[multiVault.subvaultAt(i).vault];
            if (ratio.maxRatioD18 == 0) {
                state[i].max = 0;
                state[i].min = 0;
            } else {
                state[i].max = Math.min(state[i].max, (totalAssets * ratio.maxRatioD18) / D18);
                state[i].min = Math.min(state[i].max, (totalAssets * ratio.minRatioD18) / D18);
            }
        }
    }

    /// @inheritdoc IDepositStrategy
    function calculateDepositAmounts(address vault, uint256 amount)
        external
        view
        override
        returns (DepositData[] memory data)
    {
        (Amounts[] memory state,) = calculateState(vault, true, amount);
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
        data = new DepositData[](n);
        for (uint256 i = 0; i < n && amount != 0; i++) {
            data[i].subvaultIndex = i;
            if (state[i].min == 0) {
                continue;
            }
            uint256 assets_ = Math.min(state[i].min, amount);
            state[i].max -= assets_;
            amount -= assets_;
            data[i].deposit = assets_;
        }
        for (uint256 i = 0; i < n && amount != 0; i++) {
            if (state[i].max == 0) {
                continue;
            }
            uint256 assets_ = Math.min(state[i].max, amount);
            amount -= assets_;
            data[i].deposit += assets_;
        }
        uint256 count = 0;
        for (uint256 i = 0; i < n; i++) {
            if (data[i].deposit != 0) {
                if (count != i) {
                    data[count] = data[i];
                }
                count++;
            }
        }
        assembly {
            mstore(data, count)
        }
    }

    /// @inheritdoc IWithdrawalStrategy
    function calculateWithdrawalAmounts(address vault, uint256 amount)
        external
        view
        override
        returns (WithdrawalData[] memory data)
    {
        (Amounts[] memory state, uint256 liquid) = calculateState(vault, false, amount);
        if (amount <= liquid) {
            return data;
        }
        amount -= liquid;
        uint256 n = state.length;
        data = new WithdrawalData[](n);
        for (uint256 i = 0; i < n && amount != 0; i++) {
            data[i].subvaultIndex = i;
            if (state[i].staked > state[i].max) {
                uint256 extra = state[i].staked - state[i].max;
                if (extra > amount) {
                    data[i].staked = amount;
                    amount = 0;
                } else {
                    data[i].staked = extra;
                    amount -= extra;
                }
                state[i].staked -= data[i].staked;
            }
        }
        for (uint256 i = 0; i < n && amount != 0; i++) {
            if (state[i].staked > state[i].min) {
                uint256 allowed = state[i].staked - state[i].min;
                if (allowed > amount) {
                    data[i].staked += amount;
                    amount = 0;
                } else {
                    data[i].staked += allowed;
                    amount -= allowed;
                    state[i].staked -= allowed;
                }
            }
        }
        for (uint256 i = 0; i < n && amount != 0; i++) {
            if (state[i].pending > 0) {
                if (state[i].pending > amount) {
                    data[i].pending += amount;
                    amount = 0;
                } else {
                    data[i].pending += state[i].pending;
                    amount -= state[i].pending;
                }
            }
        }
        for (uint256 i = 0; i < n && amount != 0; i++) {
            if (state[i].claimable > 0) {
                if (state[i].claimable > amount) {
                    data[i].claimable += amount;
                    amount = 0;
                } else {
                    data[i].claimable += state[i].claimable;
                    amount -= state[i].claimable;
                }
            }
        }
        for (uint256 i = 0; i < n && amount != 0; i++) {
            uint256 staked = state[i].staked;
            if (staked > 0) {
                if (staked > amount) {
                    data[i].staked += amount;
                    amount = 0;
                } else {
                    data[i].staked += staked;
                    amount -= staked;
                }
            }
        }

        require(amount == 0, "SharesStrategy: invalid state");

        uint256 count = 0;
        for (uint256 i = 0; i < n; i++) {
            if (data[i].staked + data[i].pending + data[i].claimable != 0) {
                if (count != i) {
                    data[count] = data[i];
                }
                count++;
            }
        }
        assembly {
            mstore(data, count)
        }
    }

    /// @inheritdoc IRebalanceStrategy
    function calculateRebalanceAmounts(address vault)
        external
        view
        override
        returns (RebalanceData[] memory data)
    {
        (Amounts[] memory state, uint256 liquid) = calculateState(vault, true, 0);
        uint256 n = state.length;
        data = new RebalanceData[](n);
        uint256 totalRequired = 0;
        uint256 pending = 0;
        for (uint256 i = 0; i < n; i++) {
            data[i].subvaultIndex = i;
            data[i].claim = state[i].claimable;
            liquid += state[i].claimable;
            pending += state[i].pending;
            if (state[i].staked > state[i].max) {
                data[i].request = state[i].staked - state[i].max;
                pending += data[i].request;
                state[i].staked = state[i].max;
            }
            if (state[i].min > state[i].staked) {
                totalRequired += state[i].min - state[i].staked;
            }
        }

        if (totalRequired > liquid + pending) {
            uint256 unstake = totalRequired - liquid - pending;
            for (uint256 i = 0; i < n && unstake > 0; i++) {
                if (state[i].staked > state[i].min) {
                    uint256 allowed = state[i].staked - state[i].min;
                    if (allowed > unstake) {
                        data[i].request += unstake;
                        unstake = 0;
                    } else {
                        data[i].request += allowed;
                        unstake -= allowed;
                    }
                }
            }
        }

        for (uint256 i = 0; i < n && liquid > 0; i++) {
            if (state[i].staked < state[i].min) {
                uint256 required = state[i].min - state[i].staked;
                if (required > liquid) {
                    data[i].deposit = liquid;
                    liquid = 0;
                } else {
                    data[i].deposit = required;
                    liquid -= required;
                    state[i].max -= data[i].deposit;
                }
            }
        }

        for (uint256 i = 0; i < n && liquid > 0; i++) {
            if (state[i].staked < state[i].max) {
                uint256 allowed = state[i].max - state[i].staked;
                if (allowed > liquid) {
                    data[i].deposit += liquid;
                    liquid = 0;
                } else {
                    data[i].deposit += allowed;
                    liquid -= allowed;
                }
            }
        }
    }
}
