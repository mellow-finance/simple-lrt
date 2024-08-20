// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ISTETH} from "../tokens/ISTETH.sol";
import {IWETH} from "../tokens/IWETH.sol";
import {IWSTETH} from "../tokens/IWSTETH.sol";

import {IERC4626Vault} from "../vaults/IERC4626Vault.sol";

interface IEthWrapper {
    function WETH() external view returns (address);
    function wstETH() external view returns (address);
    function stETH() external view returns (address);
    function ETH() external view returns (address);

    function deposit(
        address depositToken,
        uint256 amount,
        address vault,
        address receiver,
        address referral
    ) external payable returns (uint256 shares);
}
