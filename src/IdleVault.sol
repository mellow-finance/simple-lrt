// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {ERC4626Upgradeable, VaultControl, VaultControlStorage} from "./VaultControl.sol";
import "./interfaces/vaults/IIdleVault.sol";

contract IdleVault is IIdleVault, VaultControl, ERC20VotesUpgradeable {
    constructor() VaultControlStorage("IdleVault", 1) {}

    function initializeIdleVault(InitParams memory initParams) external initializer {
        __ERC20_init(initParams.name, initParams.symbol);
        __EIP712_init(initParams.name, "1");

        __initializeRoles(initParams.admin);
        __initializeVaultControlStorage(
            initParams.limit,
            initParams.depositPause,
            initParams.withdrawalPause,
            initParams.depositWhitelist
        );
        emit IdleVaultInitialized(initParams, block.timestamp);
    }

    function decimals()
        public
        view
        override(ERC4626Upgradeable, ERC20Upgradeable)
        returns (uint8)
    {
        return ERC4626Upgradeable.decimals();
    }

    function _update(address from, address to, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._update(from, to, amount);
    }
}
