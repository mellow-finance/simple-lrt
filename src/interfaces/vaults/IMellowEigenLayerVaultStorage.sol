// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "@eigenlayer-interfaces/IDelegationManager.sol";

import "@eigenlayer-interfaces/IRewardsCoordinator.sol";
import "@eigenlayer-interfaces/IStrategyManager.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IEigenLayerWithdrawalQueue} from "../utils/IEigenLayerWithdrawalQueue.sol";

interface IMellowEigenLayerVaultStorage {
    struct FarmData {
        address rewardToken;
        address eigenLayerFarm;
        address distributionFarm;
        address curatorTreasury;
        uint256 curatorFeeD6;
    }

    struct EigenLayerStorage {
        IEigenLayerWithdrawalQueue withdrawalQueue;
        IStrategyManager strategyManager;
        IDelegationManager delegationManager;
        IRewardsCoordinator rewardsCoordinator;
        IStrategy strategy;
        address operator;
        uint256 maxWithdrawalRequests;
        mapping(address account => IDelegationManager.Withdrawal[]) withdrawals;
        EnumerableSet.UintSet farmIds;
        mapping(uint256 => FarmData) farms;
    }

    function delegationManager() external view returns (IDelegationManager);

    function strategyManager() external view returns (IStrategyManager);

    function rewardsCoordinator() external view returns (IRewardsCoordinator);

    function strategy() external view returns (IStrategy);

    function strategyOperator() external view returns (address);

    function maxWithdrawalRequests() external view returns (uint256);
}
