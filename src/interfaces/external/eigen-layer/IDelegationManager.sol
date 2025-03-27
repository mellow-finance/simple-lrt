// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./IPauserRegistry.sol";
import "./ISignatureUtils.sol";
import "./IStrategy.sol";

interface IDelegationManager is ISignatureUtils {
    struct DelegationApproval {
        address staker;
        address operator;
        bytes32 salt;
        uint256 expiry;
    }

    struct Withdrawal {
        address staker;
        address delegatedTo;
        address withdrawer;
        uint256 nonce;
        uint32 startBlock;
        IStrategy[] strategies;
        uint256[] shares;
    }

    struct QueuedWithdrawalParams {
        IStrategy[] strategies;
        uint256[] depositShares;
        address __deprecated_withdrawer;
    }

    function delegateTo(
        address operator,
        SignatureWithExpiry memory approverSignatureAndExpiry,
        bytes32 approverSalt
    ) external;

    function undelegate(address staker) external returns (bytes32[] memory withdrawalRoots);

    function queueWithdrawals(QueuedWithdrawalParams[] calldata params)
        external
        returns (bytes32[] memory);

    function completeQueuedWithdrawal(
        Withdrawal calldata withdrawal,
        IERC20[] calldata tokens,
        bool receiveAsTokens
    ) external;

    function completeQueuedWithdrawals(
        Withdrawal[] calldata withdrawals,
        IERC20[][] calldata tokens,
        bool[] calldata receiveAsTokens
    ) external;

    function slashOperatorShares(
        address operator,
        IStrategy strategy,
        uint64 prevMaxMagnitude,
        uint64 newMaxMagnitude
    ) external;

    function delegatedTo(address staker) external view returns (address);

    function delegationApproverSaltIsSpent(address _delegationApprover, bytes32 salt)
        external
        view
        returns (bool);

    function cumulativeWithdrawalsQueued(address staker) external view returns (uint256);

    function isDelegated(address staker) external view returns (bool);

    function isOperator(address operator) external view returns (bool);

    function delegationApprover(address operator) external view returns (address);

    function getOperatorShares(address operator, IStrategy[] memory strategies)
        external
        view
        returns (uint256[] memory);

    function getOperatorsShares(address[] memory operators, IStrategy[] memory strategies)
        external
        view
        returns (uint256[][] memory);

    function getSlashableSharesInQueue(address operator, IStrategy strategy)
        external
        view
        returns (uint256);

    function getWithdrawableShares(address staker, IStrategy[] memory strategies)
        external
        view
        returns (uint256[] memory withdrawableShares, uint256[] memory depositShares);

    function getDepositedShares(address staker)
        external
        view
        returns (IStrategy[] memory, uint256[] memory);

    function depositScalingFactor(address staker, IStrategy strategy)
        external
        view
        returns (uint256);

    function getQueuedWithdrawal(bytes32 withdrawalRoot)
        external
        view
        returns (Withdrawal memory withdrawal, uint256[] memory shares);

    function getQueuedWithdrawals(address staker)
        external
        view
        returns (Withdrawal[] memory withdrawals, uint256[][] memory shares);

    function queuedWithdrawals(bytes32 withdrawalRoot)
        external
        view
        returns (Withdrawal memory withdrawal);

    function getQueuedWithdrawalRoots(address staker) external view returns (bytes32[] memory);

    function convertToDepositShares(
        address staker,
        IStrategy[] memory strategies,
        uint256[] memory withdrawableShares
    ) external view returns (uint256[] memory);

    function calculateWithdrawalRoot(Withdrawal memory withdrawal)
        external
        pure
        returns (bytes32);

    function calculateDelegationApprovalDigestHash(
        address staker,
        address operator,
        address _delegationApprover,
        bytes32 approverSalt,
        uint256 expiry
    ) external view returns (bytes32);

    function beaconChainETHStrategy() external view returns (IStrategy);

    function minWithdrawalDelayBlocks() external view returns (uint32);

    function DELEGATION_APPROVAL_TYPEHASH() external view returns (bytes32);
}
