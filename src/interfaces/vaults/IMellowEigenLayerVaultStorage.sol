// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "@eigenlayer-interfaces/IDelegationManager.sol";
import "@eigenlayer-interfaces/IStrategyManager.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IMellowEigenLayerVaultStorage {
    struct EigenLayerStorage {
        address withdrawalQueue;
        IStrategyManager strategyManager;
        IDelegationManager delegationManager;
        IStrategy strategy;
        address operator;
        uint256 maxWithdrawalRequests;
        mapping(address account => IDelegationManager.Withdrawal[]) withdrawals;
    }

    function delegationManager() external view returns (IDelegationManager);

    function strategyManager() external view returns (IStrategyManager);

    function strategy() external view returns (IStrategy);

    function strategyOperator() external view returns (address);

    function maxWithdrawalRequests() external view returns (uint256);
}
