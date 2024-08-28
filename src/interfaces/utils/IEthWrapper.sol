// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ISTETH} from "../tokens/ISTETH.sol";
import {IWETH} from "../tokens/IWETH.sol";
import {IWSTETH} from "../tokens/IWSTETH.sol";

import {IERC4626Vault} from "../vaults/IERC4626Vault.sol";

/**
 * @title IEthWrapper
 * @notice Wraps/convert input token WETH/wstETH/stETH/ETH into wstETH and deposit it into the Vault.
 * @dev IEthWrapper is an intermediate contract to handle wrapped tokens, then it deposits in favor of `msg.sender`.
 */

interface IEthWrapper {
    ///@notice Returns WETH address.
    function WETH() external view returns (address);
    ///@notice Returns wstETH address.
    function wstETH() external view returns (address);
    ///@notice Returns stETH address.
    function stETH() external view returns (address);
    ///@notice Returns ETH address.
    function ETH() external view returns (address);

    /**
     * @notice Deposits `amount` of `depositToken` into the `vault` in favor of `receiver`.
     * @param depositToken Address of deposit token.
     * @param amount Amount of deposit.
     * @param vault Address of the Vault to deposit to.
     * @param receiver Address of the receiver of shares.
     * @param referral Refferal address.
     * @return shares Result shares after deposit.
     */
    function deposit(
        address depositToken,
        uint256 amount,
        address vault,
        address receiver,
        address referral
    ) external payable returns (uint256 shares);
}
