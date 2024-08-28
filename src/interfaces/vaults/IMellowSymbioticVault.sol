// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {IERC4626Vault} from "./IERC4626Vault.sol";
import {IMellowSymbioticVaultStorage} from "./IMellowSymbioticVaultStorage.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {AccessManagerUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {
    ERC4626Upgradeable,
    IERC4626
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IVault as ISymbioticVault} from "@symbiotic/core/interfaces/vault/IVault.sol";
import {IStakerRewards} from "@symbiotic/rewards/interfaces/stakerRewards/IStakerRewards.sol";

/**
 * @title IMellowSymbioticVault
 * @notice Interface of the Vault of interaction with underlying Simbiotic Vault.
 */
interface IMellowSymbioticVault is IMellowSymbioticVaultStorage, IERC4626Vault {
    struct InitParams {
        uint256 limit;
        address symbioticVault;
        address withdrawalQueue;
        address admin;
        bool depositPause;
        bool withdrawalPause;
        bool depositWhitelist;
        string name;
        string symbol;
    }

    /**
     * @notice Initialize state of the Vault.
     * @param initParams Struct with initialize params.
     * 
     * @custom:requirements
     * - MUST not be initialized at the call.
     */
    function initialize(InitParams memory initParams) external;

    /**
     * @notice Set farm for the Vault
     * @param farmId Id of Farm.
     * @param farmData Struct with Farm data.
     * 
     * @custom:requirements
     * - `FarmData.rewardToken` MUST be Vault or Simbiotic Vault.
     * - `farmData.curatorFeeD6` MUST be not greather than 10**6.
     */
    function setFarm(uint256 farmId, FarmData memory farmData) external;

    /**
     * @notice Returns amount of `asset` that can be claimed for the `account`.
     * @param account Receiver address.
     * @return claimableAssets Amount of `asset` that can be claimed.
     */
    function claimableAssetsOf(address account) external view returns (uint256 claimableAssets);

    /**
     * @notice Returns amount of `asset` that are at the withdrawal queue for the `account`.
     * @param account Receiver address.
     * @return pendingAssets Amount of `asset` in withdrawal queue and can not be claimed at this time.
     */
    function pendingAssetsOf(address account) external view returns (uint256 pendingAssets);

    /**
     * @notice Finalize withdrawal process for the account and transfer assets to the recipient.
     * @param account Withdrawal address.
     * @param recipient Receiver address.
     * @param maxAmount Maximum amount of assets to withdraw.
     * @return shares Actual claimed shares.
     *
     * @custom:requirements
     * - `account` MUST be equal to `msg.sender`
     *
     * @custom:effects
     * - Finalize withdrawal process and transfers not more than `maxAmount` of `asset` to the `recipient`.
     */
    function claim(address account, address recipient, uint256 maxAmount)
        external
        returns (uint256);

    /**
     * @notice Pushes all avaliable balance of underlying token into Simbiotic.
     * @return symbioticVaultStaked Actual staked share inte Simbiotic.
     *
     * @custom:effects
     * - Transfers whole balance of `asset` of the Vault to the Simbiotic Vault.
     * - Emits SymbioticPushed event.
     */
    function pushIntoSymbiotic() external returns (uint256 symbioticVaultStaked);

    /**
     * @notice Pushes rewards to the Curator of the Vault.
     * @param farmId Id of Farm.
     * @param symbioticRewardsData Specific Simbiotic data for claimRewards() method.
     *
     * @custom:effects
     * - Transfers a part of Simbiotic reward token balance of the Vault to the Curator as fees.
     * - Emits RewardsPushed event.
     */
    function pushRewards(uint256 farmId, bytes calldata symbioticRewardsData) external;

    /**
     * @notice Returns all balances for the account.
     * @param account Account address.
     * @return accountAssets Total amount of assets belongs to the account.
     * @return accountInstantAssets Amount of assets that can be withdrawn instantly.
     * @return accountShares Total amount of shares belongs to the account.
     * @return accountInstantShares Shares that can be withdrawn instantly.
     */
    function getBalances(address account)
        external
        view
        returns (
            uint256 accountAssets,
            uint256 accountInstantAssets,
            uint256 accountShares,
            uint256 accountInstantShares
        );

    event RewardsPushed(
        uint256 indexed farmId, uint256 rewardAmount, uint256 curatorFee, uint256 timestamp
    );

    event SymbioticPushed(address sender, uint256 vaultAmount);
}
