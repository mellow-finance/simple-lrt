// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {ERC4626Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

import {IERC4626Vault} from "./IERC4626Vault.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title IIdleVault
 * @notice 
 */
interface IIdleVault is IERC4626Vault {
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
     * @notice Initialize state of the Vault.
     * @param initParams Struct with initialize params.
     * 
     * @custom:requirements
     * - MUST not be initialized at the call.
     * 
     * @custom:effects
     * - Emits IdleVaultInitialized event.
     */
    function initialize(InitParams memory initParams) external;

    event IdleVaultInitialized(InitParams initParams, uint256 timestamp);
}
