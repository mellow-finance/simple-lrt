// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ERC4626Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

import {IERC4626Vault} from "./IERC4626Vault.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title IIdleVault
 * @notice Interface for an Idle Vault that extends the IERC4626Vault standard.
 *         This contract handles vault initialization with specific parameters.
 */
interface IIdleVault is IERC4626Vault {
    /**
     * @notice Struct to store the initialization parameters for the vault.
     * @param asset The address of the underlying ERC20 token.
     * @param limit The maximum limit for deposits.
     * @param depositPause Flag indicating if deposits are paused.
     * @param withdrawalPause Flag indicating if withdrawals are paused.
     * @param depositWhitelist Flag indicating if a whitelist is required for deposits.
     * @param admin The address of the admin managing the vault.
     * @param name The name of the vault token.
     * @param symbol The symbol of the vault token.
     */
    struct InitParams {
        address asset;
        uint256 limit;
        bool depositPause;
        bool withdrawalPause;
        bool depositWhitelist;
        address admin;
        string name;
        string symbol;
    }

    /**
     * @notice Initializes the vault with the provided parameters.
     * @param initParams A struct containing the initialization parameters.
     *
     * @custom:requirements
     * - The vault MUST not have been initialized previously.
     *
     * @custom:effects
     * - Sets up the initial state of the vault, including asset, limits, pause states, whitelist, and metadata.
     * - Emits the `IdleVaultInitialized` event.
     */
    function initialize(InitParams memory initParams) external;

    /**
     * @notice Emitted when the Idle Vault is successfully initialized.
     * @param initParams The initialization parameters used during setup.
     * @param timestamp The timestamp when the vault was initialized.
     */
    event IdleVaultInitialized(InitParams initParams, uint256 timestamp);
}
