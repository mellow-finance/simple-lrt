// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/vaults/IMellowEigenLayerVaultStorage.sol";

abstract contract MellowEigenLayerVaultStorage is IMellowEigenLayerVaultStorage, Initializable {
    using EnumerableSet for EnumerableSet.UintSet;

    bytes32 private immutable storageSlotRef;

    constructor(bytes32 name_, uint256 version_) {
        storageSlotRef = keccak256(
            abi.encode(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            "mellow.simple-lrt.storage.MellowEigenLayerVaultStorage", name_, version_
                        )
                    )
                ) - 1
            )
        ) & ~bytes32(uint256(0xff));
    }

    function __initializeMellowEigenLayerVaultStorage(EigenLayerStorage memory eigenLayerStorage) internal onlyInitializing {
        _setEigenLayerDelegationManager(eigenLayerStorage.delegationManager);
        _setEigenLayerStrategyManager(eigenLayerStorage.strategyManager);
        _setEigenLayerStrategy(eigenLayerStorage.strategy);
        _setEigenLayerStrategyOperator(eigenLayerStorage.operator);
    }

    function eigenLayerDelegationManager() public view returns (IDelegationManager) {
        return _eigenLayerStorage().delegationManager;
    }

    function eigenLayerStrategyManager() public view returns (IStrategyManager) {
        return _eigenLayerStorage().strategyManager;
    }

    function eigenLayerStrategy() public view returns (IStrategy) {
        return _eigenLayerStorage().strategy;
    }

    function eigenLayerStrategyOperator() public view returns (address) {
        return _eigenLayerStorage().operator;
    }

    function _setEigenLayerDelegationManager(IDelegationManager _delegationManager) internal {
        EigenLayerStorage storage s = _eigenLayerStorage();
        s.delegationManager = _delegationManager;
        emit EigenLayerDelegationManagerSet(address(_delegationManager), block.timestamp);
    }

    function _setEigenLayerStrategyManager(IStrategyManager _strategyManager) internal {
        EigenLayerStorage storage s = _eigenLayerStorage();
        s.strategyManager = _strategyManager;
        emit EigenLayerStrategyManagerSet(address(_strategyManager), block.timestamp);
    }

    function _setEigenLayerStrategy(IStrategy _strategy) internal {
        EigenLayerStorage storage s = _eigenLayerStorage();
        s.strategy = _strategy;
        emit EigenLayerStrategySet(address(_strategy), block.timestamp);
    }

    function _setEigenLayerStrategyOperator(address _operator) internal {
        EigenLayerStorage storage s = _eigenLayerStorage();
        s.operator = _operator;
        emit EigenLayerStrategyOperatorSet(address(_operator), block.timestamp);
    }

    function _eigenLayerStorage() private view returns (EigenLayerStorage storage $) {
        bytes32 slot = storageSlotRef;
        assembly {
            $.slot := slot
        }
    }
}
