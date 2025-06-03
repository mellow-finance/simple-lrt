// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IAllocationManager {
    struct OperatorSet {
        address avs;
        uint32 id;
    }

    struct Allocation {
        uint64 currentMagnitude;
        int128 pendingDiff;
        uint32 effectBlock;
    }

    struct AllocationDelayInfo {
        uint32 delay;
        bool isSet;
        uint32 pendingDelay;
        uint32 effectBlock;
    }

    struct RegistrationStatus {
        bool registered;
        uint32 slashableUntil;
    }

    struct StrategyInfo {
        uint64 maxMagnitude;
        uint64 encumberedMagnitude;
    }

    struct SlashingParams {
        address operator;
        uint32 operatorSetId;
        address[] strategies;
        uint256[] wadsToSlash;
        string description;
    }

    struct AllocateParams {
        OperatorSet operatorSet;
        address[] strategies;
        uint64[] newMagnitudes;
    }

    struct RegisterParams {
        address avs;
        uint32[] operatorSetIds;
        bytes data;
    }

    struct DeregisterParams {
        address operator;
        address avs;
        uint32[] operatorSetIds;
    }

    struct CreateSetParams {
        uint32 operatorSetId;
        address[] strategies;
    }

    function initialize(address initialOwner, uint256 initialPausedStatus) external;

    function slashOperator(address avs, SlashingParams calldata params) external;

    function modifyAllocations(address operator, AllocateParams[] calldata params) external;

    function clearDeallocationQueue(
        address operator,
        address[] calldata strategies,
        uint16[] calldata numToClear
    ) external;

    function registerForOperatorSets(address operator, RegisterParams calldata params) external;

    function deregisterFromOperatorSets(DeregisterParams calldata params) external;

    function setAllocationDelay(address operator, uint32 delay) external;

    function setAVSRegistrar(address avs, address registrar) external;

    function updateAVSMetadataURI(address avs, string calldata metadataURI) external;

    function createOperatorSets(address avs, CreateSetParams[] calldata params) external;

    function addStrategiesToOperatorSet(
        address avs,
        uint32 operatorSetId,
        address[] calldata strategies
    ) external;

    function removeStrategiesFromOperatorSet(
        address avs,
        uint32 operatorSetId,
        address[] calldata strategies
    ) external;

    function getOperatorSetCount(address avs) external view returns (uint256);

    function getAllocatedSets(address operator) external view returns (OperatorSet[] memory);

    function getAllocatedStrategies(address operator, OperatorSet memory operatorSet)
        external
        view
        returns (address[] memory);

    function getAllocation(address operator, OperatorSet memory operatorSet, address strategy)
        external
        view
        returns (Allocation memory);

    function getAllocations(
        address[] memory operators,
        OperatorSet memory operatorSet,
        address strategy
    ) external view returns (Allocation[] memory);

    function getStrategyAllocations(address operator, address strategy)
        external
        view
        returns (OperatorSet[] memory, Allocation[] memory);

    function getEncumberedMagnitude(address operator, address strategy)
        external
        view
        returns (uint64);

    function getAllocatableMagnitude(address operator, address strategy)
        external
        view
        returns (uint64);

    function getMaxMagnitude(address operator, address strategy) external view returns (uint64);

    function getMaxMagnitudes(address operator, address[] calldata strategies)
        external
        view
        returns (uint64[] memory);

    function getMaxMagnitudes(address[] calldata operators, address strategy)
        external
        view
        returns (uint64[] memory);

    function getMaxMagnitudesAtBlock(
        address operator,
        address[] calldata strategies,
        uint32 blockNumber
    ) external view returns (uint64[] memory);

    function getAllocationDelay(address operator)
        external
        view
        returns (bool isSet, uint32 delay);

    function getRegisteredSets(address operator)
        external
        view
        returns (OperatorSet[] memory operatorSets);

    function isMemberOfOperatorSet(address operator, OperatorSet memory operatorSet)
        external
        view
        returns (bool);

    function isOperatorSet(OperatorSet memory operatorSet) external view returns (bool);

    function getMembers(OperatorSet memory operatorSet)
        external
        view
        returns (address[] memory operators);

    function getMemberCount(OperatorSet memory operatorSet) external view returns (uint256);

    function getAVSRegistrar(address avs) external view returns (address);

    function getStrategiesInOperatorSet(OperatorSet memory operatorSet)
        external
        view
        returns (address[] memory strategies);

    function getMinimumSlashableStake(
        OperatorSet memory operatorSet,
        address[] memory operators,
        address[] memory strategies,
        uint32 futureBlock
    ) external view returns (uint256[][] memory slashableStake);

    function getAllocatedStake(
        OperatorSet memory operatorSet,
        address[] memory operators,
        address[] memory strategies
    ) external view returns (uint256[][] memory slashableStake);

    function isOperatorSlashable(address operator, OperatorSet memory operatorSet)
        external
        view
        returns (bool);
}
