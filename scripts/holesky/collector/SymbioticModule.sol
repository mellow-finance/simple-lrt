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

    address public immutable networkRegistry;
    address public immutable operatorRegistry;
    address public immutable operatorOptInService;

    uint256 public immutable MAX_RESPONSE;

    constructor(
        address networkRegistry_,
        address operatorRegistry_,
        address operatorOptInService_,
        uint256 maxResponse_
    ) {
        networkRegistry = networkRegistry_;
        operatorRegistry = operatorRegistry_;
        operatorOptInService = operatorOptInService_;
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
}
