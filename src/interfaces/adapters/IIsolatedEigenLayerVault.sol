// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IEigenLayerWithdrawalQueue} from "../queues/IEigenLayerWithdrawalQueue.sol";
import {IIsolatedEigenLayerVaultFactory} from "./IIsolatedEigenLayerVaultFactory.sol";
import {IDelegationManager} from "@eigenlayer-interfaces/IDelegationManager.sol";
import {IRewardsCoordinator} from "@eigenlayer-interfaces/IRewardsCoordinator.sol";
import {ISignatureUtils} from "@eigenlayer-interfaces/ISignatureUtils.sol";
import {IStrategy, IStrategyManager} from "@eigenlayer-interfaces/IStrategyManager.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20, IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title IIsolatedEigenLayerVault
 * @notice Interface for interacting with an isolated EigenLayer vault.
 * @dev This interface provides methods for delegation, deposits, withdrawals,
 *      and reward claims specific to the EigenLayer protocol.
 */
interface IIsolatedEigenLayerVault {
    /**
     * @notice Initializes the isolated EigenLayer vault.
     * @dev Sets the factory, primary vault, and underlying asset addresses.
     * @param vault_ Address of the primary vault interacting with this isolated vault.
     */
    function initialize(address vault_) external;

    /**
     * @notice Returns the address of the factory that created this vault.
     * returns the factory address.
     */
    function factory() external view returns (address);

    /**
     * @notice Returns the address of the underlying vault associated with this isolated vault.
     * returns the vault address.
     */
    function vault() external view returns (address);

    /**
     * @notice Returns the address of the underlying asset managed by this vault.
     * returns the asset address.
     */
    function asset() external view returns (address);

    /**
     * @notice Delegates to a specified operator via the given manager, using a signature for verification.
     * @param manager The address of the delegation manager responsible for handling delegations.
     * @param operator The address of the operator to which delegation is being assigned.
     * @param signature The signature and expiry details for validating the delegation.
     * @param salt A unique value to ensure signature uniqueness.
     */
    function delegateTo(
        address manager,
        address operator,
        ISignatureUtils.SignatureWithExpiry memory signature,
        bytes32 salt
    ) external;

    /**
     * @notice Deposits a specified amount of assets into the given strategy via the specified manager.
     * @param manager The address of the strategy manager handling the deposit.
     * @param strategy The address of the strategy to which the assets will be deposited.
     * @param assets The amount of assets to deposit.
     */
    function deposit(address manager, address strategy, uint256 assets) external;

    /**
     * @notice Withdraws a specified amount of assets through the given queue.
     * @param queue The address of the withdrawal queue handling the request.
     * @param receiver The address to which the withdrawn assets will be sent.
     * @param request The amount of assets to withdraw.
     * @param flag A boolean flag to control specific withdrawal behavior.
     */
    function withdraw(address queue, address receiver, uint256 request, bool flag) external;

    /**
     * @notice Processes a reward claim using the given rewards coordinator and farm data.
     * @param coordinator The rewards coordinator handling the claim.
     * @param farmData The Merkle claim data containing details of the rewards to be processed.
     * @param rewardToken The ERC20 token representing the reward being claimed.
     */
    function processClaim(
        IRewardsCoordinator coordinator,
        IRewardsCoordinator.RewardsMerkleClaim memory farmData,
        IERC20 rewardToken
    ) external;

    /**
     * @notice Claims a withdrawal from the given delegation manager using the specified data.
     * @param manager The address of the delegation manager handling the withdrawal.
     * @param data The withdrawal details including strategies and shares.
     * @return assets The amount of assets successfully claimed.
     */
    function claimWithdrawal(
        IDelegationManager manager,
        IDelegationManager.Withdrawal calldata data
    ) external returns (uint256 assets);

    /**
     * @notice Queues multiple withdrawal requests with the specified delegation manager.
     * @param manager The address of the delegation manager handling the withdrawal requests.
     * @param requests An array of withdrawal request parameters to be queued.
     */
    function queueWithdrawals(
        IDelegationManager manager,
        IDelegationManager.QueuedWithdrawalParams[] calldata requests
    ) external;
}
