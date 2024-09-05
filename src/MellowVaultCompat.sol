// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/vaults/IMellowVaultCompat.sol";

import {MellowSymbioticVault} from "./MellowSymbioticVault.sol";

contract MellowVaultCompat is IMellowVaultCompat, MellowSymbioticVault {
    // ERC20 storage slots
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
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

    /// @inheritdoc IMellowVaultCompat
    function migrateApproval(address from, address to) public {
        uint256 allowance_ = _allowances[from][to];
        if (allowance_ == 0) {
            return;
        }
        delete _allowances[from][to];
        super._approve(from, to, allowance_, false);
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
     * @inheritdoc ERC20Upgradeable
     * @notice Updates the allowance for the spender, ensuring any pre-existing allowances in the old storage are migrated before performing the update.
     * @param owner The address allowing the spender to spend tokens.
     * @param spender The address allowed to spend tokens.
     * @param value The amount of tokens the spender is allowed to spend.
     * @param emitEvent A flag to signal if the approval event should be emitted.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent)
        internal
        virtual
        override(ERC20Upgradeable)
    {
        migrateApproval(owner, spender);
        super._approve(owner, spender, value, emitEvent);
    }

    /**
     * @inheritdoc IERC20
     * @notice Returns the allowance for the given owner and spender, combining both pre-migration and post-migration allowances.
     * @param owner The address allowing the spender to spend tokens.
     * @param spender The address allowed to spend tokens.
     * @return The combined allowance for the owner and spender.
     */
    function allowance(address owner, address spender)
        public
        view
        virtual
        override(ERC20Upgradeable, IERC20)
        returns (uint256)
    {
        return _allowances[owner][spender] + super.allowance(owner, spender);
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
