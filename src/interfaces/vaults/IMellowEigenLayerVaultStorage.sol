// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../eigen/IDelegationManager.sol";
import "../eigen/IStrategyManager.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IMellowEigenLayerVaultStorage {
    struct EigenLayerStorage {
        IStrategyManager strategyManager;
        IDelegationManager delegationManager;
        IStrategy strategy;
        address operator;
    }

    function eigenLayerDelegationManager() external view returns (IDelegationManager);

    function eigenLayerStrategyManager() external view returns (IStrategyManager);
    
    function eigenLayerStrategy() external view returns (IStrategy);

    function eigenLayerStrategyOperator() external view returns (address);

    event EigenLayerDelegationManagerSet(address delegationManager, uint256 timestamp);

    event EigenLayerStrategyManagerSet(address strategyManager, uint256 timestamp);

    event EigenLayerStrategySet(address eigenLayerStrategy, uint256 timestamp);

    event EigenLayerStrategyOperatorSet(address operator, uint256 timestamp);
}
