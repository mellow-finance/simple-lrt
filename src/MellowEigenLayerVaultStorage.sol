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
                            "mellow.simple-lrt.storage.MellowEigenLayerVaultStorage",
                            name_,
                            version_
                        )
                    )
                ) - 1
            )
        ) & ~bytes32(uint256(0xff));
    }

    function __initializeMellowEigenLayerVaultStorage(
        IDelegationManager delegationManager,
        IStrategyManager strategyManager,
        IStrategy strategy,
        address operator,
        uint256 claimWithdrawalsMax
    ) internal onlyInitializing {
        _setEigenLayerDelegationManager(delegationManager);
        _setEigenLayerStrategyManager(strategyManager);
        _setEigenLayerStrategy(strategy);
        _setEigenLayerStrategyOperator(operator);
        _setEigenLayerClaimWithdrawalsMax(claimWithdrawalsMax);
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

    function eigenLayerClaimWithdrawalsMax() public view returns (uint256) {
        return _eigenLayerStorage().claimWithdrawalsMax;
    }

    function eigenLayerAccountWithdrawals(address account)
        public
        view
        returns (IDelegationManager.Withdrawal[] memory)
    {
        mapping(address account => IDelegationManager.Withdrawal[]) storage s =
            _getEigenLayerWithdrawalQueue();
        return s[account];
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

    function _setEigenLayerClaimWithdrawalsMax(uint256 _claimWithdrawalsMax) internal {
        EigenLayerStorage storage s = _eigenLayerStorage();
        s.claimWithdrawalsMax = _claimWithdrawalsMax;
        emit EigenLayerClaimWithdrawalsMaxSet(_claimWithdrawalsMax, block.timestamp);
    }

    function _getEigenLayerWithdrawalQueue()
        internal
        view
        returns (mapping(address account => IDelegationManager.Withdrawal[]) storage)
    {
        EigenLayerStorage storage s = _eigenLayerStorage();
        return s.withdrawals;
    }

    function _eigenLayerStorage() private view returns (EigenLayerStorage storage $) {
        bytes32 slot = bytes32(uint256(storageSlotRef));
        assembly {
            $.slot := slot
        }
    }
}
