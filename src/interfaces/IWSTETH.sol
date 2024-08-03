// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

interface IWSTETH {
    function submit(uint256 _stETHAmount) external payable;
}
