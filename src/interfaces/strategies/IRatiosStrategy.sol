// // SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IDefaultCollateral, IERC20} from "../tokens/IDefaultCollateral.sol";
import {IMultiVault} from "../vaults/IMultiVault.sol";
import {IDepositStrategy} from "./IDepositStrategy.sol";
import {IRebalanceStrategy} from "./IRebalanceStrategy.sol";
import {IWithdrawalStrategy} from "./IWithdrawalStrategy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

interface IRatiosStrategy is IDepositStrategy, IWithdrawalStrategy, IRebalanceStrategy {
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

    function getRatios(address vault, address subvault)
        external
        view
        returns (uint256 minRatioD18, uint256 maxRatioD18);

    function setRatios(address vault, address[] calldata subvaults, Ratio[] calldata ratios)
        external;

    function calculateState(address vault, bool isDeposit, uint256 increment)
        external
        view
        returns (Amounts[] memory state, uint256 liquid);
}
