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

/**
 * @title IMellowVaultCompat
 * @notice This interface facilitates the migration of vaults from the older Mellow Vault to the newer Mellow Symbiotic Vault.
 * @dev Migration logic includes transferring user balances from old storage to new storage and gradually decreasing the old `_totalSupply`.
 *      Once the old `_totalSupply` reaches zero, full migration to `MellowSymbioticVault` can be completed, removing redundant checks.
 */
interface IMellowVaultCompat is IMellowSymbioticVault {
    /**
     * @notice Returns the current total supply of the migrating vault.
     * @dev The total supply decreases as users are migrated to the new vault.
     *      When it reaches zero, complete migration to the `MellowSymbioticVault` can be finalized.
     * @return compatTotalSupply The remaining total supply of the migrating vault.
     */
    function compatTotalSupply() external view returns (uint256);

    /**
     * @notice Migrates the balances of multiple users from the old ERC20 storage to the new ERC20Upgradeable storage.
     * @param users An array of addresses corresponding to the users whose balances are being migrated.
     *
     * @custom:effects
     * - Transfers the user balances from the old vault storage to the new storage.
     */
    function migrateMultiple(address[] calldata users) external;

    /**
     * @notice Migrates the balance of a single user from the old ERC20 storage to the new ERC20Upgradeable storage.
     * @param user The address of the user whose balance is being migrated.
     *
     * @custom:effects
     * - Transfers the user's balance from the old vault storage to the new storage.
     */
    function migrate(address user) external;
}
