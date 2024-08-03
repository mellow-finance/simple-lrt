// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

interface IWSTETH {
    function wrap(uint256 _stETHAmount) external returns (uint256);
}
