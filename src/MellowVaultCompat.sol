// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/vaults/IEthVaultCompat.sol";

import {MellowSymbioticVault} from "./MellowSymbioticVault.sol";

/*
    This contract is an intermediate step in the migration from mellow-lrt/src/Vault.sol to simple-lrt/src/MellowSymbioticVault.sol.
    Migration logic:

    1. On every transfer/mint/burn, the _update function is called, which transfers the user's balance from the old storage slot to the new one.
    2. At the same time, the old _totalSupply decreases. This allows tracking how many balances still need to be migrated.
    3. Once the old _totalSupply reaches zero, further migration to MellowSymbioticVault can be performed. This will remove unnecessary checks.
*/
contract MellowVaultCompat is IEthVaultCompat, MellowSymbioticVault {
    // ERC20 slots
    mapping(address account => uint256) private _balances;
    bytes32 private _gap;
    uint256 private _totalSupply;
    bytes32[16] private _reserved;

    constructor(bytes32 name_, uint256 version_) MellowSymbioticVault(name_, version_) {}

    // decreases with migrations
    // when it becomes zero -> we can migrate to MellowSymbioticVault
    function compatTotalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function migrateMultiple(address[] calldata users) external {
        for (uint256 i = 0; i < users.length; ++i) {
            migrate(users[i]);
        }
    }

    // helps migrate user balance from default ERC20 stores to ERC20Upgradeable stores
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

    // ERC20Upgradeable override
    function _update(address from, address to, uint256 value) internal virtual override {
        migrate(from);
        migrate(to);
        super._update(from, to, value);
    }

    function balanceOf(address account)
        public
        view
        override(IERC20, ERC20Upgradeable)
        returns (uint256)
    {
        return _balances[account] + super.balanceOf(account);
    }

    function totalSupply() public view override(IERC20, ERC20Upgradeable) returns (uint256) {
        return _totalSupply + super.totalSupply();
    }
}
