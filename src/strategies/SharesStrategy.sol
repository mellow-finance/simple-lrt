// // SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/strategies/IDepositStrategy.sol";
import "../interfaces/strategies/IRebalanceStrategy.sol";
import "../interfaces/strategies/IWithdrawalStrategy.sol";
import "../interfaces/vaults/IMultiVault.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract SharesStrategy is IDepositStrategy, IWithdrawalStrategy, IRebalanceStrategy {
    struct Ratio {
        uint64 minRatioD18;
        uint64 maxRatioD18;
    }

    struct State {
        uint256 assets;
        uint256 maxDeposit;
    }

    uint256 public constant D18 = 1e18;
    bytes32 public constant SHARES_STRATEGY_SET_RATIO_ROLE =
        keccak256("SHARES_STRATEGY_SET_RATIO_ROLE");

    mapping(address vault => mapping(address subvault => Ratio)) private _ratios;

    function calculateState(address vault)
        public
        view
        returns (uint256 totalAssets, State[] memory state)
    {
        IMultiVault multiVault = IMultiVault(vault);
        uint256 n = multiVault.subvaultsCount();
        state = new State[](n);
        for (uint256 i = 0; i < n; i++) {
            (uint256 claimable, uint256 pending, uint256 staked) = multiVault.maxWithdraw(i);
            uint256 assets = claimable + pending + staked;
            uint256 maxDeposit = multiVault.maxDeposit(i);
            state[i] = State(assets, maxDeposit);
            totalAssets += assets;
        }
        totalAssets += IERC20(IERC4626(vault).asset()).balanceOf(vault);
        IDefaultCollateral collateral = IDefaultCollateral(multiVault.symbioticDefaultCollateral());
        if (address(collateral) != address(0)) {
            totalAssets += collateral.balanceOf(vault);
        }
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

    function calculateDepositAmounts(address vault, uint256 amount)
        external
        view
        override
        returns (DepositData[] memory subvaultsData)
    {
        (uint256 totalAssets, State[] memory state) = calculateState(vault);
        uint256 n = state.length;
        mapping(address subvault => Ratio) storage ratios_ = _ratios[vault];
        IMultiVault multiVault = IMultiVault(vault);
        uint256 nonZeroAmounts = 0;
        for (uint256 i = 0; i < n; i++) {
            Ratio memory ratio = ratios_[multiVault.subvaultAt(i).vault];
            if (ratio.maxRatioD18 == 0) {
                state[i].maxDeposit = 0;
            } else {
                // uint256 maxAssets = Math.mulDiv(
                //     totalAssets,
                //     ratioD18,
                //     D18
                // );
                // if (maxAssets > )
            }
        }
    }

    function calculateWithdrawalAmounts(address vault, uint256 amount)
        external
        view
        override
        returns (WithdrawalData[] memory subvaultsData)
    {
        (uint256 totalAssets, State[] memory state) = calculateState(vault);
    }

    function calculateRebalaneAmounts(address vault)
        external
        view
        override
        returns (RebalanceData[] memory subvaultsData)
    {
        (uint256 totalAssets, State[] memory state) = calculateState(vault);
    }
}
