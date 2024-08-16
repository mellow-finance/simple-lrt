// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {ERC4626Upgradeable, VaultControl, VaultControlStorage} from "./VaultControl.sol";
import "./interfaces/vaults/IIdleVault.sol";

contract IdleVault is IIdleVault, VaultControl, ERC20VotesUpgradeable {
    constructor() VaultControlStorage("IdleVault", 1) {}

    function initializeIdleVault(
        uint256 _limit,
        bool _depositPause,
        bool _withdrawalPause,
        bool _depositWhitelist,
        address _admin,
        string memory name,
        string memory symbol
    ) external initializer {
        __ERC20_init(name, symbol);
        __EIP712_init(name, "1");

        __initializeRoles(_admin);
        __initializeVaultControlStorage(_limit, _depositPause, _withdrawalPause, _depositWhitelist);
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
