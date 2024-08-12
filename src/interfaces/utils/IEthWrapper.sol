// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../tokens/IWETH.sol";
import "../tokens/ISTETH.sol";
import "../tokens/IWSTETH.sol";

interface IEthWrapper {
    function WETH() external view returns (address);
    function wstETH() external view returns (address);
    function stETH() external view returns (address);
    function ETH() external view returns (address);
}
