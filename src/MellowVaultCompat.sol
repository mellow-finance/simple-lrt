// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/vaults/IMellowVaultCompat.sol";

import {MellowSymbioticVault} from "./MellowSymbioticVault.sol";

contract MellowVaultCompat is IMellowVaultCompat, MellowSymbioticVault {
    // ERC20 storage slots
    mapping(address => uint256) private _balances;
    bytes32 private _gap; // Reserved gap for storage layout alignment
    uint256 private _totalSupply; // Tracks the total supply of tokens before migration
    bytes32[16] private _reserved; // Reserved storage space for future upgrades

    constructor(bytes32 name_, uint256 version_) MellowSymbioticVault(name_, version_) {}

    /// @inheritdoc IMellowVaultCompat
    function compatTotalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /// @inheritdoc IMellowVaultCompat
    function migrateMultiple(address[] calldata users) external {
        for (uint256 i = 0; i < users.length; ++i) {
            migrate(users[i]);
        }
    }

    /// @inheritdoc IMellowVaultCompat
    function migrate(address user) public {
        uint256 balance = _balances[user];
        if (balance == 0) {
            return;
        }
        delete _balances[user];
        unchecked {
            _totalSupply -= balance;
        }
        emit Transfer(user, address(0), balance);
        _mint(user, balance);
    }

    /**
     * @inheritdoc ERC20Upgradeable
     * @notice Updates balances for token transfers, ensuring any pre-existing balances in the old storage are migrated before performing the update.
     * @param from The address sending the tokens.
     * @param to The address receiving the tokens.
     * @param value The amount of tokens being transferred.
     */
    function _update(address from, address to, uint256 value) internal virtual override {
        migrate(from);
        migrate(to);
        super._update(from, to, value);
    }

    /**
     * @inheritdoc IERC20
     * @notice Returns the balance of the given account, combining both pre-migration and post-migration balances.
     * @param account The address of the account to query.
     * @return The combined balance of the account.
     */
    function balanceOf(address account)
        public
        view
        override(IERC20, ERC20Upgradeable)
        returns (uint256)
    {
        return _balances[account] + super.balanceOf(account);
    }

    /**
     * @inheritdoc IERC20
     * @notice Returns the total supply of tokens, combining both pre-migration and post-migration supplies.
     * @return The combined total supply of tokens.
     */
    function totalSupply() public view override(IERC20, ERC20Upgradeable) returns (uint256) {
        return _totalSupply + super.totalSupply();
    }
}
