// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IOracle {
    function priceX96() external view returns (uint256);
}
