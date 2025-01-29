// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/utils/Create2.sol";

import "../adapters/IsolatedEigenLayerVaultFactory.sol";

contract EigenLayerFactoryHelper {
    IsolatedEigenLayerVaultFactory public immutable factory;

    constructor(address factory_) {
        factory = IsolatedEigenLayerVaultFactory(factory_);
    }

    function calculateAddress(address owner, address strategy, address operator)
        external
        view
        returns (address)
    {
        return Create2.computeAddress(
            factory.key(owner, strategy, operator),
            keccak256(
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(
                        factory.isolatedVaultSingleton(),
                        factory.proxyAdmin(),
                        abi.encodeCall(IsolatedEigenLayerVault.initialize, (owner))
                    )
                )
            ),
            address(factory)
        );
    }
}
