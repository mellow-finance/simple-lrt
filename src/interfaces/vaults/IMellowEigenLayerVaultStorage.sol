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
        uint256 claimWithdrawalsMax;
        mapping(address account => IDelegationManager.Withdrawal[]) withdrawals;
    }

    function eigenLayerDelegationManager() external view returns (IDelegationManager);

    function eigenLayerStrategyManager() external view returns (IStrategyManager);

    function eigenLayerStrategy() external view returns (IStrategy);

    function eigenLayerStrategyOperator() external view returns (address);

    function eigenLayerClaimWithdrawalsMax() external view returns (uint256);

    event EigenLayerNonceIncreased(uint256 nonce, uint256 timestamp);

    event EigenLayerDelegationManagerSet(address delegationManager, uint256 timestamp);

    event EigenLayerStrategyManagerSet(address strategyManager, uint256 timestamp);

    event EigenLayerStrategySet(address eigenLayerStrategy, uint256 timestamp);

    event EigenLayerStrategyOperatorSet(address operator, uint256 timestamp);

    event EigenLayerClaimWithdrawalsMaxSet(uint256 maxClaimWithdrawals, uint256 timestamp);
}
