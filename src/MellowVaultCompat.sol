// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/vaults/IMellowVaultCompat.sol";

import {MellowSymbioticVault} from "./MellowSymbioticVault.sol";

contract MellowVaultCompat is IMellowVaultCompat, MellowSymbioticVault {
    // ERC20 slots
    mapping(address account => uint256) private _balances;
    bytes32 private _gap;
    uint256 private _totalSupply;
    bytes32[16] private _reserved;

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

    /// @inheritdoc ERC20Upgradeable
    function _update(address from, address to, uint256 value) internal virtual override {
        migrate(from);
        migrate(to);
        super._update(from, to, value);
    }

    /// @inheritdoc IERC20
    function balanceOf(address account)
        public
        view
        override(IERC20, ERC20Upgradeable)
        returns (uint256)
    {
        return _balances[account] + super.balanceOf(account);
    }

    /// @inheritdoc IERC20
    function totalSupply() public view override(IERC20, ERC20Upgradeable) returns (uint256) {
        return _totalSupply + super.totalSupply();
    }
}
