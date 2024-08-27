// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {ERC20Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC4626Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {
    Context, ERC20, IERC20, IERC20Metadata
} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./IMellowSymbioticVault.sol";

/*
    This contract is an intermediate step in the migration from mellow-lrt/src/Vault.sol to simple-lrt/src/MellowSymbioticVault.sol.
    Migration logic:

    1. On every transfer/mint/burn, the _update function is called, which transfers the user's balance from the old storage slot to the new one.
    2. At the same time, the old _totalSupply decreases. This allows tracking how many balances still need to be migrated.
    3. Once the old _totalSupply reaches zero, further migration to MellowSymbioticVault can be performed. This will remove unnecessary checks.
*/
interface IMellowVaultCompat is IMellowSymbioticVault {
    // decreases with migrations
    // when it becomes zero -> we can migrate to MellowSymbioticVault
    function compatTotalSupply() external view returns (uint256);

    function migrateMultiple(address[] calldata users) external;

    // helps migrate user balance from default ERC20 stores to ERC20Upgradeable stores
    function migrate(address user) external;
}
