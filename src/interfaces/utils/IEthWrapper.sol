// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IWETH} from "../tokens/IWETH.sol";
import {ISTETH} from "../tokens/ISTETH.sol";
import {IWSTETH} from "../tokens/IWSTETH.sol";

interface IEthWrapper {
    function WETH() external view returns (address);
    function wstETH() external view returns (address);
    function stETH() external view returns (address);
    function ETH() external view returns (address);
}
