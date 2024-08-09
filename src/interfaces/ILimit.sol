// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

interface ILimit {
    function limit() external view returns (uint256);
    function totalSupply() external view returns (uint256);
}
