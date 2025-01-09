// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ERC4626Vault} from "./ERC4626Vault.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

abstract contract MellowVaultCompat is ERC4626Vault {
    bytes32 private constant ERC20CompatStorageSlot = 0;
    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC20")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC20UpgradeableStorageSlot =
        0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;

    function _getERC20CompatStorage() private pure returns (ERC20Storage storage $) {
        assembly {
            $.slot := ERC20CompatStorageSlot
        }
    }

    function _getERC20UpgradeableStorage() private pure returns (ERC20Storage storage $) {
        assembly {
            $.slot := ERC20UpgradeableStorageSlot
        }
    }

    function compatTotalSupply() external view returns (uint256) {
        return _getERC20CompatStorage()._totalSupply;
    }

    function migrateMultiple(address[] calldata users) external {
        for (uint256 i = 0; i < users.length; ++i) {
            migrate(users[i]);
        }
    }

    function migrate(address user) public {
        ERC20Storage storage compatStorage = _getERC20CompatStorage();
        uint256 balance = compatStorage._balances[user];
        if (balance == 0) {
            return;
        }
        ERC20Storage storage upgradeableStorage = _getERC20UpgradeableStorage();
        delete compatStorage._balances[user];
        unchecked {
            upgradeableStorage._balances[user] += balance;
            compatStorage._totalSupply -= balance;
            upgradeableStorage._totalSupply += balance;
        }
    }

    function migrateApproval(address from, address to) public {
        ERC20Storage storage compatStorage = _getERC20CompatStorage();
        uint256 allowance_ = compatStorage._allowances[from][to];
        if (allowance_ == 0) {
            return;
        }
        delete compatStorage._allowances[from][to];
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
        return
            _getERC20CompatStorage()._allowances[owner][spender] + super.allowance(owner, spender);
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
        return _getERC20CompatStorage()._balances[account] + super.balanceOf(account);
    }

    /**
     * @inheritdoc IERC20
     * @notice Returns the total supply of tokens, combining both pre-migration and post-migration supplies.
     * @return The combined total supply of tokens.
     */
    function totalSupply() public view override(IERC20, ERC20Upgradeable) returns (uint256) {
        return _getERC20CompatStorage()._totalSupply + super.totalSupply();
    }
}
