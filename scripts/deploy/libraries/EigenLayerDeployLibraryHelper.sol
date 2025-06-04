// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../src/adapters/EigenLayerAdapter.sol";
import "../../../src/adapters/EigenLayerWstETHAdapter.sol";

contract EigenLayerDeployLibraryHelper {
    function deployEigenLayerAdapter(
        bool isWstETH,
        bytes32 salt,
        address factory,
        address multiVault,
        address strategyManager,
        address rewardsCoordinator,
        address wsteth
    ) external returns (address) {
        return isWstETH
            ? address(
                new EigenLayerWstETHAdapter{salt: salt}(
                    factory,
                    multiVault,
                    IStrategyManager(strategyManager),
                    IRewardsCoordinator(rewardsCoordinator),
                    wsteth
                )
            )
            : address(
                new EigenLayerAdapter{salt: salt}(
                    factory,
                    multiVault,
                    IStrategyManager(strategyManager),
                    IRewardsCoordinator(rewardsCoordinator)
                )
            );
    }
}
