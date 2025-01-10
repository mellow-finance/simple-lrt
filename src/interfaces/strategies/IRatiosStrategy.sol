// // SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IDefaultCollateral, IERC20} from "../tokens/IDefaultCollateral.sol";
import {
    IMultiVault,
    IMultiVaultStorage,
    IProtocolAdapter,
    IWithdrawalQueue
} from "../vaults/IMultiVault.sol";
import {IDepositStrategy} from "./IDepositStrategy.sol";
import {IRebalanceStrategy} from "./IRebalanceStrategy.sol";
import {IWithdrawalStrategy} from "./IWithdrawalStrategy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title IRatiosStrategy
 * @notice Interface for a strategy that manages deposits, withdrawals, and rebalancing
 *         based on predefined ratios for sub-vaults.
 * @dev Extends `IDepositStrategy`, `IWithdrawalStrategy`, and `IRebalanceStrategy`.
 */
interface IRatiosStrategy is IDepositStrategy, IWithdrawalStrategy, IRebalanceStrategy {
    /**
     * @notice Represents the minimum and maximum ratios for a sub-vault.
     * @dev Ratios are represented as fixed-point numbers with 18 decimals.
     * @param minRatioD18 The minimum allowable ratio for the sub-vault.
     * @param maxRatioD18 The maximum allowable ratio for the sub-vault.
     */
    struct Ratio {
        uint64 minRatioD18;
        uint64 maxRatioD18;
    }

    /**
     * @notice Represents various amounts related to the state of a sub-vault.
     * @dev Includes minimum and maximum amounts, claimable assets, pending withdrawals, and staked assets.
     * @param min The minimum amount for the sub-vault.
     * @param max The maximum amount for the sub-vault.
     * @param claimable The amount of assets that can currently be claimed.
     * @param pending The amount of assets pending withdrawal.
     * @param staked The amount of assets currently staked in the sub-vault.
     */
    struct Amounts {
        uint256 min;
        uint256 max;
        uint256 claimable;
        uint256 pending;
        uint256 staked;
    }

    /**
     * @notice Returns the constant used for fixed-point arithmetic (10^18).
     * returns the value of `10^18`.
     */
    function D18() external view returns (uint256);

    /**
     * @notice Returns the role identifier for setting ratios in the strategy.
     * returns the role identifier as a `bytes32` value.
     */
    function RATIOS_STRATEGY_SET_RATIOS_ROLE() external view returns (bytes32);

    /**
     * @notice Retrieves the minimum and maximum ratios for a specific vault and sub-vault.
     * @param vault The address of the vault.
     * @param subvault The address of the sub-vault.
     * @return minRatioD18 The minimum ratio for the sub-vault.
     * @return maxRatioD18 The maximum ratio for the sub-vault.
     */
    function ratios(address vault, address subvault)
        external
        view
        returns (uint64 minRatioD18, uint64 maxRatioD18);

    /**
     * @notice Sets the ratios for a vault's sub-vaults.
     * @dev Can only be called by accounts with the `RATIOS_STRATEGY_SET_RATIOS_ROLE` role.
     * @param vault The address of the vault.
     * @param subvaults An array of sub-vault addresses.
     * @param ratios An array of `Ratio` structs specifying the new ratios.
     */
    function setRatios(address vault, address[] calldata subvaults, Ratio[] calldata ratios)
        external;

    /**
     * @notice Calculates the state of a vault based on the current or future deposit/withdrawal state.
     * @dev This function returns an array of `Amounts` structs for each sub-vault, along with the liquid amount.
     * @param vault The address of the vault.
     * @param isDeposit A boolean indicating whether the state is being calculated for a deposit (`true`) or withdrawal (`false`).
     * @param increment The amount of assets being deposited or withdrawn.
     * @return state An array of `Amounts` structs for each sub-vault.
     * @return liquid The amount of liquid assets remaining after the operation.
     */
    function calculateState(address vault, bool isDeposit, uint256 increment)
        external
        view
        returns (Amounts[] memory state, uint256 liquid);

    /**
     * @notice Emitted when ratios for a vault's sub-vaults are updated.
     * @param vault The address of the vault whose ratios were updated.
     * @param subvaults The array of sub-vault addresses whose ratios were updated.
     * @param ratios The array of `Ratio` structs specifying the updated ratios.
     */
    event RatiosSet(address indexed vault, address[] subvaults, Ratio[] ratios);
}
