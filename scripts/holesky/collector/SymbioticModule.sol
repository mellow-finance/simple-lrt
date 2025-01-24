// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

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

contract SymbioticModule {
    struct OperatorData {
        address operator;
        uint256 shares;
    }

    struct NetworkData {
        address network;
        uint96 subnetwork;
        uint256 limit;
        OperatorData[] operators;
    }

    address public immutable networkRegistry;
    address public immutable operatorRegistry;
    address public immutable operatorOptInService;

    constructor(
        address networkRegistry_,
        address operatorRegistry_,
        address operatorOptInService_
    ) {
        networkRegistry = networkRegistry_;
        operatorRegistry = operatorRegistry_;
        operatorOptInService = operatorOptInService_;
    }

    function getLimits(address symbioticVault) external view returns (Network[] memory networks) {
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

        address[] memory networks = new address[](IRegistry(networkRegistry).totalEntities());
        {
            uint256 index = 0;
            for (uint256 i = 0; i < networks.length; i++) {
                address network = IRegistry(networkRegistry).entity(i);
            }
            assembly {
                mstore(networks, index)
            }
        }
    }
}
