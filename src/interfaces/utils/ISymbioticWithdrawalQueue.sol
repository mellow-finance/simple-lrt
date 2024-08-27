// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IMellowSymbioticVault} from "../vaults/IMellowSymbioticVault.sol";
import {IVault as ISymbioticVault} from "@symbiotic/core/interfaces/vault/IVault.sol";

import {IWithdrawalQueue} from "./IWithdrawalQueue.sol";

interface ISymbioticWithdrawalQueue is IWithdrawalQueue {
    struct EpochData {
        bool isClaimed;
        uint256 sharesToClaim;
        uint256 claimableAssets;
    }

    struct AccountData {
        mapping(uint256 epoch => uint256 shares) sharesToClaim;
        uint256 claimableAssets;
        uint256 claimEpoch;
    }

    /**
     * @notice Returns address of the linked Vault.
     * @return vault Address of the linked Vault.
     */
    function vault() external view returns (address);

    /**
     * @notice Returns address of the underlying Simbiotic Vault.
     * @return simbioticVault Address of the underlying Simbiotic Vault.
     */
    function symbioticVault() external view returns (ISymbioticVault);

    /**
     * @notice Returns address of the collateral token.
     * @return collateralAddress Address of the collateral token.
     */
    function collateral() external view returns (address);

    /**
     * @notice Returns current epoch of the Simbiotic Vault.
     * @return currentEpoch Current epoch of the Simbiotic Vault.
     */
    function getCurrentEpoch() external view returns (uint256);

    /**
     * @notice Returns `EpochData` for `epoch`.
     * @param epoch Number of the epoch,
     * @return epochData Specific `EpochData` for the `epoch`.
     */
    function epochData(uint256 epoch) external view returns (EpochData memory);

    /**
     * @notice Returns total amount of queued `assets`  
     * @return assets Amount of `assets` in the queue.
     */
    function pendingAssets() external view returns (uint256);

    /**
     * @notice Returns total balance of `account` in the queue, both pendinf and claimable.
     * @param account Address of the account.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @notice Returns amount of `asset` that are at the withdrawal queue for the `account`. 
     * @param account Receiver address.
     * @return assets Amount of `asset` in withdrawal queue and can not be claimed at this time.
     */
    function pendingAssetsOf(address account) external view returns (uint256 assets);

    /**
     * @notice Returns amount of `asset` that can be claimed for the `account`. 
     * @param account Receiver address.
     * @return assets Amount of `asset` that can be claimed.
     */
    function claimableAssetsOf(address account) external view returns (uint256 assets);

    /**
     * @notice Pushes to the Withdrawal Queue the withdraw `amount` from `account`.
     * @param account Address of the account to be withdrawn. 
     * @param amount Amount of assets  to be withdrawn.
     * 
     * @custom:effects
     * - Emits WithdrawalRequested event.
     */
    function request(address account, uint256 amount) external;

    /**
     * @notice Claims assets from the Simbiotic vault in favor of the Withdrawal Queue till the epoch `epoch`.
     * @dev Pulls only requested amount of assets.
     * @param epoch Number of the epoch.
     * 
     * @custom:effects
     * - Emits EpochClaimed event.
     */
    function pull(uint256 epoch) external;

    /**
     * @notice Finalizes process for the requested withdrawal in favor of `recipient`.
     * @param account Address of the account to be withdrawn. 
     * @param recipient Address of the recipient of withrawing assets.
     * @param maxAmount Maximum of amount of assets to be withdrawn.
     */
    function claim(address account, address recipient, uint256 maxAmount)
        external
        returns (uint256 amount);

    /**
     * @notice Claimed from the Simbiotic Vault till the current epoch.
     * @dev Updates `epochData` and `accountData` mappings.
     * @param account Address of the account for which assets will be claimable.
     * 
     * @custom:effects
     * - Emits EpochClaimed event.
     */
    function handlePendingEpochs(address account) external;

    event WithdrawalRequested(address account, uint256 epoch, uint256 amount);
    event EpochClaimed(uint256 epoch, uint256 claimedAssets);
    event EpochClaimFailed(uint256 epoch);
    event Claimed(address account, address recipient, uint256 amount);
}
