// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

interface IDefaultBond {
    function deposit(address recipient, uint256 amount) external returns (uint256);

    function withdraw(address recipient, uint256 amount) external returns (uint256);
}
