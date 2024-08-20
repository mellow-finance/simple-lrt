// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {ERC4626Vault} from "./ERC4626Vault.sol";
import {VaultControlStorage} from "./VaultControl.sol";
import "./interfaces/vaults/IIdleVault.sol";

contract IdleVault is IIdleVault, ERC4626Vault, ERC20VotesUpgradeable {
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

    function decimals()
        public
        view
        override(ERC4626Upgradeable, ERC20Upgradeable, IERC20Metadata)
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
