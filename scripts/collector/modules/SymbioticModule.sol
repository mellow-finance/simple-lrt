// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@symbiotic/core/interfaces/IDelegatorFactory.sol";
import "@symbiotic/core/interfaces/INetworkRegistry.sol";
import "@symbiotic/core/interfaces/IOperatorRegistry.sol";
import "@symbiotic/core/interfaces/ISlasherFactory.sol";
import "@symbiotic/core/interfaces/IVaultConfigurator.sol";
import "@symbiotic/core/interfaces/IVaultFactory.sol";
import "@symbiotic/core/interfaces/common/IRegistry.sol";
import "@symbiotic/core/interfaces/delegator/IFullRestakeDelegator.sol";
import "@symbiotic/core/interfaces/delegator/INetworkRestakeDelegator.sol";
import "@symbiotic/core/interfaces/service/INetworkMiddlewareService.sol";
import "@symbiotic/core/interfaces/service/IOptInService.sol";
import "@symbiotic/core/interfaces/vault/IVault.sol";

contract SymbioticModule {
    struct OperatorData {
        address operator;
        uint256 slashableStake;
    }

    struct NetworkData {
        address network;
        uint96 subnetwork;
        uint256 limit;
        OperatorData[] operators;
    }

    struct SubnetworkData {
        address network;
        uint96 id;
        bytes32 subnetwork;
        address[] operators;
        uint256[] operatorShares;
        uint256 maxNetworkLimit;
        uint256 slashableStake;
    }

    address public immutable networkRegistry;
    address public immutable operatorRegistry;
    address public immutable operatorOptInService;
    address public immutable operatorOptInNetworkService;
    uint256 public immutable MAX_RESPONSE;

    constructor(
        address networkRegistry_,
        address operatorRegistry_,
        address operatorOptInService_,
        address operatorOptInNetworkService_,
        uint256 maxResponse_
    ) {
        networkRegistry = networkRegistry_;
        operatorRegistry = operatorRegistry_;
        operatorOptInService = operatorOptInService_;
        operatorOptInNetworkService = operatorOptInNetworkService_;
        MAX_RESPONSE = maxResponse_;
    }

    function getLimits(address symbioticVault)
        external
        view
        returns (NetworkData[] memory networks)
    {
        IBaseDelegator delegator = IBaseDelegator(IVault(symbioticVault).delegator());
        address[] memory operators = new address[](IRegistry(operatorRegistry).totalEntities());
        {
            uint256 index = 0;
            for (uint256 i = 0; i < operators.length; i++) {
                address operator = IRegistry(operatorRegistry).entity(i);
                if (IOptInService(operatorOptInService).isOptedIn(operator, symbioticVault)) {
                    operators[index++] = operator;
                }
            }
            assembly {
                mstore(operators, index)
            }
        }

        {
            uint256 n = IRegistry(networkRegistry).totalEntities();
            networks = new NetworkData[](Math.min(n, MAX_RESPONSE));
            uint256 index = 0;

            OperatorData[] memory operators_ = new OperatorData[](operators.length);
            for (uint256 i = 0; i < n; i++) {
                address network = IRegistry(networkRegistry).entity(i);
                for (uint96 identifier = 0;; identifier++) {
                    bytes32 subnetwork = bytes32(uint256(uint160(network)) << 96 | identifier);
                    uint256 limit = delegator.maxNetworkLimit(subnetwork);
                    if (limit == 0 && identifier >= 2) {
                        break;
                    }
                    limit = Math.min(
                        limit, INetworkRestakeDelegator(address(delegator)).networkLimit(subnetwork)
                    );
                    if (limit == 0) {
                        continue;
                    }
                    networks[index] = NetworkData(network, identifier, limit, new OperatorData[](0));
                    uint256 j = 0;
                    for (uint256 k = 0; k < operators.length; k++) {
                        address operator = operators[k];
                        uint256 slashableStake = delegator.stake(subnetwork, operator);
                        if (slashableStake != 0) {
                            operators_[j++] = OperatorData(operator, slashableStake);
                        }
                    }
                    networks[index].operators = new OperatorData[](j);
                    for (uint256 k = 0; k < j; k++) {
                        networks[index].operators[k] = operators_[k];
                    }
                    index++;
                }
            }
            assembly {
                mstore(networks, index)
            }
        }
    }

    function extendArray(address[] memory a) public pure returns (address[] memory b) {
        b = new address[](a.length * 2);
        for (uint256 i = 0; i < a.length; i++) {
            b[i] = a[i];
        }
        return b;
    }

    function extendArray(bytes32[] memory a) public pure returns (bytes32[] memory b) {
        b = new bytes32[](a.length * 2);
        for (uint256 i = 0; i < a.length; i++) {
            b[i] = a[i];
        }
        return b;
    }

    function extendArray(uint256[] memory a) public pure returns (uint256[] memory b) {
        b = new uint256[](a.length * 2);
        for (uint256 i = 0; i < a.length; i++) {
            b[i] = a[i];
        }
        return b;
    }

    function getSubnetworkData(address symbioticVault)
        external
        view
        returns (SubnetworkData[] memory response, uint256 totalStake, uint256 totalDelegatedStake)
    {
        totalStake = IVault(symbioticVault).totalStake();
        INetworkRestakeDelegator delegator =
            INetworkRestakeDelegator(IVault(symbioticVault).delegator());
        address[] memory operators = new address[](16);
        {
            uint256 n = IRegistry(operatorRegistry).totalEntities();
            uint256 index = 0;
            for (uint256 i = 0; i < n; i++) {
                address operator = IRegistry(operatorRegistry).entity(i);
                if (IOptInService(operatorOptInService).isOptedIn(operator, symbioticVault)) {
                    operators[index++] = operator;
                    if (index == operators.length) {
                        operators = extendArray(operators);
                    }
                }
            }
            assembly {
                mstore(operators, index)
            }
        }

        bytes32[] memory subnetworks = new bytes32[](16);
        {
            uint256 n = IRegistry(networkRegistry).totalEntities();
            uint256 index = 0;
            for (uint256 i = 0; i < n; i++) {
                address network = IRegistry(networkRegistry).entity(i);
                for (uint96 identifier = 0;; identifier++) {
                    bytes32 subnetwork = bytes32(uint256(uint160(network)) << 96 | identifier);
                    uint256 limit = delegator.maxNetworkLimit(subnetwork);
                    if (limit == 0) {
                        if (identifier > 3) {
                            break;
                        }
                        continue;
                    }
                    subnetworks[index++] = subnetwork;
                    if (index == subnetworks.length) {
                        subnetworks = extendArray(subnetworks);
                    }
                }
            }
            assembly {
                mstore(subnetworks, index)
            }
        }

        {
            response = new SubnetworkData[](subnetworks.length);
            uint256 index = 0;

            address[] memory networkOperators = new address[](16);
            uint256[] memory operatorShares = new uint256[](16);
            for (uint256 i = 0; i < subnetworks.length; i++) {
                bytes32 subnetwork = subnetworks[i];
                uint96 id = uint96(uint256(subnetwork) & type(uint96).max);
                address network = address(uint160(uint256(subnetwork) >> 96));
                SubnetworkData memory data = SubnetworkData({
                    network: network,
                    id: id,
                    subnetwork: subnetwork,
                    operators: new address[](0),
                    operatorShares: new uint256[](0),
                    maxNetworkLimit: delegator.maxNetworkLimit(subnetwork),
                    slashableStake: 0
                });

                uint256 iterator = 0;
                for (uint256 j = 0; j < operators.length; j++) {
                    address operator = operators[j];
                    if (IOptInService(operatorOptInNetworkService).isOptedIn(operator, network)) {
                        networkOperators[iterator] = operator;
                        operatorShares[iterator] =
                            delegator.operatorNetworkShares(subnetwork, operator);
                        if (operatorShares[iterator] != 0) {
                            data.slashableStake += delegator.stake(subnetwork, operator);
                        }
                        iterator++;
                        if (iterator == networkOperators.length) {
                            networkOperators = extendArray(networkOperators);
                            operatorShares = extendArray(operatorShares);
                        }
                    }
                }
                if (iterator == 0) {
                    continue;
                }

                data.operators = new address[](iterator);
                data.operatorShares = new uint256[](iterator);
                for (uint256 j = 0; j < iterator; j++) {
                    data.operators[j] = networkOperators[j];
                    data.operatorShares[j] = operatorShares[j];
                }
                totalDelegatedStake += data.slashableStake;
                response[index++] = data;
            }
            assembly {
                mstore(response, index)
            }
        }
    }
}
