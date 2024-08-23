// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {ERC4626Vault} from "./ERC4626Vault.sol";
import {VaultControlStorage} from "./VaultControlStorage.sol";
import "./interfaces/vaults/IIdleVault.sol";

contract IdleVault is IIdleVault, ERC4626Vault {
    constructor() VaultControlStorage("IdleVault", 1) {}

    function initialize(InitParams memory initParams) external initializer {
        __initializeERC4626(
            initParams.admin,
            initParams.limit,
            initParams.depositPause,
            initParams.withdrawalPause,
            initParams.depositWhitelist,
            initParams.asset,
            initParams.name,
            initParams.symbol
        );
        emit IdleVaultInitialized(initParams, block.timestamp);
    }
}
