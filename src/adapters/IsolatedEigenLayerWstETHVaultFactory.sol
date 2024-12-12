// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./IsolatedEigenLayerVaultFactory.sol";
import "./IsolatedEigenLayerWstETHVault.sol";

contract IsolatedEigenLayerWstETHVaultFactory is IsolatedEigenLayerVaultFactory {
    address public immutable wsteth;

    constructor(address delegation_, address claimer_, address wsteth_)
        IsolatedEigenLayerVaultFactory(delegation_, claimer_)
    {
        wsteth = wsteth_;
    }

    function _create(address owner, bytes32 key_) internal override returns (address) {
        return address(new IsolatedEigenLayerWstETHVault{salt: key_}(owner, wsteth));
    }
}
