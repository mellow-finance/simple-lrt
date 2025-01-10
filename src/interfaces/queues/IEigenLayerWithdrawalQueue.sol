// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IIsolatedEigenLayerVault} from "../adapters/IIsolatedEigenLayerVault.sol";
import {IWithdrawalQueue} from "./IWithdrawalQueue.sol";
import {IDelegationManager} from "@eigenlayer-interfaces/IDelegationManager.sol";
import {IStrategy} from "@eigenlayer-interfaces/IStrategy.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title IEigenLayerWithdrawalQueue
 * @notice Interface for managing withdrawal requests and handling assets in an EigenLayer context.
 * @dev Extends `IWithdrawalQueue` and introduces additional structures and methods specific to EigenLayer integrations.
 */
interface IEigenLayerWithdrawalQueue is IWithdrawalQueue {
    /**
     * @notice Structure representing the details of a withdrawal request.
     * @dev Contains information about the withdrawal, including its delegation data, status, and associated assets.
     * @param data The withdrawal data structure from the `IDelegationManager`.
     * @param isClaimed A boolean indicating if the withdrawal has been claimed.
     * @param assets The total assets associated with the withdrawal.
     * @param shares The total shares associated with the withdrawal.
     * @param sharesOf A mapping of account addresses to their corresponding shares in the withdrawal.
     */
    struct WithdrawalData {
        IDelegationManager.Withdrawal data;
        bool isClaimed;
        uint256 assets;
        uint256 shares;
        mapping(address account => uint256) sharesOf;
    }

    /**
     * @notice Structure representing account-specific data related to withdrawals.
     * @dev Tracks claimable assets, pending withdrawals, and transferred withdrawals for an account.
     * @param claimableAssets The amount of assets claimable by the account.
     * @param withdrawals A set of pending withdrawal indices.
     * @param transferedWithdrawals A set of transferred withdrawal indices.
     */
    struct AccountData {
        uint256 claimableAssets;
        EnumerableSet.UintSet withdrawals;
        EnumerableSet.UintSet transferedWithdrawals;
    }

    /**
     * @notice Returns the address of the isolated vault associated with the withdrawal queue.
     * returns the address of the isolated vault.
     */
    function isolatedVault() external view returns (address);

    /**
     * @notice Returns the address of the claimer contract associated with the withdrawal queue.
     * returns the address of the claimer contract.
     */
    function claimer() external view returns (address);

    /**
     * @notice Returns the address of the delegation manager used for withdrawals.
     * returns the address of the delegation manager contract.
     */
    function delegation() external view returns (address);

    /**
     * @notice Returns the address of the strategy associated with this withdrawal queue.
     * returns the address of the strategy contract.
     */
    function strategy() external view returns (address);

    /**
     * @notice Returns the address of the operator managing the strategy.
     * returns the address of the operator.
     */
    function operator() external view returns (address);

    /**
     * @notice Returns the block number at which the latest withdrawal can be processed.
     * returns the block number of the latest withdrawable request.
     */
    function latestWithdrawableBlock() external view returns (uint256);

    /**
     * @notice Requests a withdrawal for the specified account and amount of assets.
     * @param account The address of the account initiating the withdrawal.
     * @param assets The amount of assets to withdraw.
     * @param isSelfRequested A boolean indicating if the request is self-initiated.
     */
    function request(address account, uint256 assets, bool isSelfRequested) external;

    /**
     * @notice Handles pending withdrawals for the specified account.
     * @dev Processes all pending withdrawals for the account and updates the account's claimable assets.
     * @param account The address of the account whose withdrawals are being handled.
     */
    function handleWithdrawals(address account) external;

    /**
     * @notice Accepts pending assets for the specified account and withdrawals.
     * @dev Transfers pending withdrawals from the account's queue to the claimable assets pool.
     * @param account The address of the account accepting the pending assets.
     * @param withdrawals_ An array of withdrawal indices to be accepted.
     */
    function acceptPendingAssets(address account, uint256[] calldata withdrawals_) external;
}
