// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../src/interfaces/adapters/IIsolatedEigenLayerVault.sol";
import "../../../src/interfaces/adapters/IIsolatedEigenLayerVaultFactory.sol";
import "../../../src/interfaces/external/eigen-layer/IAllocationManager.sol";

contract EigenLayerModule {
    struct Limit {
        address avs;
        uint32 id;
        uint64 magnitude;
    }

    IAllocationManager public immutable allocationManager;

    constructor(IAllocationManager _allocationManager) {
        allocationManager = _allocationManager;
    }

    function getLimits(IIsolatedEigenLayerVault isolatedVault)
        public
        view
        returns (Limit[] memory limits, uint64 maxMagnitude)
    {
        (, address strategy, address operator,) = IIsolatedEigenLayerVaultFactory(
            isolatedVault.factory()
        ).instances(address(isolatedVault));
        (
            IAllocationManager.OperatorSet[] memory operatorSets,
            IAllocationManager.Allocation[] memory allocations
        ) = allocationManager.getStrategyAllocations(operator, strategy);
        maxMagnitude = allocationManager.getMaxMagnitude(operator, strategy);
        limits = new Limit[](allocations.length);
        for (uint256 i = 0; i < allocations.length; i++) {
            limits[i] = Limit({
                avs: operatorSets[i].avs,
                id: operatorSets[i].id,
                magnitude: allocations[i].currentMagnitude
            });
        }
    }
}
