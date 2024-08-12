// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {SimpleVault, VaultStorage} from "./SimpleVault.sol";
import {EthWrapper} from "./EthWrapper.sol";

contract EthVaultV2 is SimpleVault, EthWrapper {
    constructor() SimpleVault("EthVaultV2", 1) {}

    function _deposit(address depositToken, uint256 amount) internal override {
        _wrap(depositToken, amount);
    }
}
