// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@symbiotic/core/interfaces/IDelegatorFactory.sol";
import "@symbiotic/core/interfaces/INetworkRegistry.sol";
import "@symbiotic/core/interfaces/IOperatorRegistry.sol";
import "@symbiotic/core/interfaces/ISlasherFactory.sol";
import "@symbiotic/core/interfaces/IVaultConfigurator.sol";
import "@symbiotic/core/interfaces/IVaultFactory.sol";

import "@symbiotic/core/interfaces/common/IEntity.sol";
import "@symbiotic/core/interfaces/common/IRegistry.sol";
import "@symbiotic/core/interfaces/delegator/IFullRestakeDelegator.sol";
import "@symbiotic/core/interfaces/delegator/INetworkRestakeDelegator.sol";
import "@symbiotic/core/interfaces/delegator/IOperatorNetworkSpecificDelegator.sol";
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

    constructor(
        address networkRegistry_,
        address operatorRegistry_,
        address operatorOptInService_,
        address operatorOptInNetworkService_
    ) {
        networkRegistry = networkRegistry_;
        operatorRegistry = operatorRegistry_;
        operatorOptInService = operatorOptInService_;
        operatorOptInNetworkService = operatorOptInNetworkService_;
    }

    function getLimits(address symbioticVault)
        external
        view
        returns (NetworkData[] memory networks)
    {
        (SubnetworkData[] memory response,,) = getSubnetworkData(symbioticVault);
        IBaseDelegator delegator = IBaseDelegator(IVault(symbioticVault).delegator());
        networks = new NetworkData[](response.length);
        for (uint256 i = 0; i < response.length; i++) {
            networks[i].network = response[i].network;
            networks[i].subnetwork = response[i].id;
            networks[i].limit = response[i].maxNetworkLimit;
            uint256 n = response[i].operators.length;
            networks[i].operators = new OperatorData[](n);
            for (uint256 j = 0; j < n; j++) {
                networks[i].operators[j] = OperatorData(
                    response[i].operators[j],
                    delegator.stake(response[i].subnetwork, response[i].operators[j])
                );
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

    function getOperatorSpecificData(address symbioticVault)
        public
        view
        returns (SubnetworkData[] memory response, uint256 totalStake, uint256 totalDelegatedStake)
    {
        totalStake = IVault(symbioticVault).totalStake();
        totalDelegatedStake = 0;
        IOperatorNetworkSpecificDelegator delegator =
            IOperatorNetworkSpecificDelegator(IVault(symbioticVault).delegator());
        address network = delegator.network();
        address operator = delegator.operator();

        uint256 iterator = 0;
        uint96[] memory ids = new uint96[](50);
        {
            //
            uint96 capId = uint96(uint256(keccak256(abi.encodePacked(operator))));
            bytes32 subnetwork = bytes32(uint256(uint160(network)) << 96 | capId);
            if (delegator.maxNetworkLimit(subnetwork) != 0) {
                ids[iterator++] = capId;
            }
        }
        for (uint256 i = 0;; i++) {
            uint96 identifier = uint96(i);
            bytes32 subnetwork = bytes32(uint256(uint160(network)) << 96 | identifier);
            if (delegator.maxNetworkLimit(subnetwork) != 0) {
                ids[iterator++] = identifier;
            }
            if (i < 50) {
                continue;
            }
            if (iterator == 0) {
                ids[iterator++] = 0;
                break;
            }
            if (ids[iterator - 1] > i) {
                if (i > 50) {
                    break;
                }
            } else if (i - ids[iterator - 1] > 10) {
                break;
            }
        }

        assembly {
            mstore(ids, iterator)
        }
        response = new SubnetworkData[](ids.length);
        address[] memory operators = new address[](1);
        operators[0] = operator;
        uint256[] memory operatorShares = new uint256[](1);
        operatorShares[0] = 1 ether;
        for (uint256 i = 0; i < ids.length; i++) {
            bytes32 subnetwork = bytes32(uint256(uint160(network)) << 96 | ids[i]);
            response[i] = SubnetworkData({
                network: network,
                id: ids[i],
                subnetwork: subnetwork,
                operators: operators,
                operatorShares: operatorShares,
                maxNetworkLimit: delegator.maxNetworkLimit(subnetwork),
                slashableStake: delegator.stake(subnetwork, operator)
            });
            totalDelegatedStake += response[i].slashableStake;
        }
    }

    function getSubnetworkData(address symbioticVault)
        public
        view
        returns (SubnetworkData[] memory response, uint256 totalStake, uint256 totalDelegatedStake)
    {
        INetworkRestakeDelegator delegator =
            INetworkRestakeDelegator(IVault(symbioticVault).delegator());
        if (IEntity(address(delegator)).TYPE() == 3) {
            return getOperatorSpecificData(symbioticVault);
        }
        totalStake = IVault(symbioticVault).totalStake();
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
