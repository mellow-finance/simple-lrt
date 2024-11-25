// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IDefaultCollateral} from "../tokens/IDefaultCollateral.sol";

import {IDepositStrategy} from "../strategies/IDepositStrategy.sol";
import {IRebalanceStrategy} from "../strategies/IRebalanceStrategy.sol";
import {IWithdrawalStrategy} from "../strategies/IWithdrawalStrategy.sol";
import {IEigenLayerWithdrawalQueue} from "../utils/IEigenLayerWithdrawalQueue.sol";
import {IWithdrawalQueue} from "../utils/IWithdrawalQueue.sol";
import {IERC4626Vault} from "./IERC4626Vault.sol";
import {IMellowSymbioticVaultStorage} from "./IMellowSymbioticVaultStorage.sol";
import {IDelegationManager} from "@eigenlayer-interfaces/IDelegationManager.sol";
import {IRewardsCoordinator} from "@eigenlayer-interfaces/IRewardsCoordinator.sol";
import {IStrategy, IStrategyManager} from "@eigenlayer-interfaces/IStrategyManager.sol";
import {AccessManagerUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    ERC4626Upgradeable,
    IERC4626
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IVault as ISymbioticVault} from "@symbiotic/core/interfaces/vault/IVault.sol";
import {IStakerRewards} from "@symbiotic/rewards/interfaces/stakerRewards/IStakerRewards.sol";

interface IMultiVaultStorage {
    enum SubvaultType {
        SYMBIOTIC,
        EIGEN_LAYER,
        ERC4626
    }

    struct Subvault {
        SubvaultType subvaultType;
        address vault;
        address withdrawalQueue;
    }

    struct RewardData {
        address distributionFarm;
        address curatorTreasury;
        address token;
        uint256 curatorFeeD6;
        SubvaultType subvaultType;
        bytes data;
    }

    struct MultiStorage {
        address depositStrategy;
        address withdrawalStrategy;
        address rebalanceStrategy;
        Subvault[] subvaults;
        mapping(address subvault => uint256 index) indexOfSubvault;
        mapping(uint256 id => RewardData) rewardData;
        EnumerableSet.UintSet farmIds;
        address symbioticDefaultCollateral;
        address eigenLayerStrategyManager;
        address eigenLayerRewardsCoordinator;
        bytes32[16] _gap;
    }

    function subvaultsCount() external view returns (uint256);

    function subvaultAt(uint256 index) external view returns (Subvault memory);

    function indexOfSubvault(address subvault) external view returns (uint256);

    function symbioticDefaultCollateral() external view returns (IDefaultCollateral);

    function eigenLayerStrategyManager() external view returns (address);

    function eigenLayerDelegationManager() external view returns (IDelegationManager);

    function eigenLayerRewardsCoordinator() external view returns (address);

    function depositStrategy() external view returns (address);

    function withdrawalStrategy() external view returns (address);

    function rebalanceStrategy() external view returns (address);

    function rewardData(uint256 farmId) external view returns (RewardData memory);
}
