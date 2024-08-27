// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {
    ERC4626Upgradeable,
    IERC4626
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC4626Vault is IERC4626 {
    event ReferralDeposit(uint256 asset, address reciever, address referral);

    /**
     * @notice Mints Vault shares to receiver by depositing exactly assets of underlying tokens.
     * @param assets Amount of underlying tokens.
     * @param receiver Receiver address.
     * @param referral Refferal address.
     * 
     * @custom:requirements
     * - The `assets` to deposit MUST be greater than 0.
     * 
     * @custom:effects
     * - Transfers the underlying token with `assets` from the sender to the Vault.
     * - Mints the `shares` of LRT to the `receiver`.
     * - Deposits amount `assets` to the underlying bond.
     * - Emits Deposit event.
     */
    function deposit(uint256 assets, address receiver, address referral)
        external
        returns (uint256 shares);
}
