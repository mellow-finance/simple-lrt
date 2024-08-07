// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

interface ISymbioticVault {
    function deposit(
        address onBehalfOf,
        uint256 amount
    ) external returns (uint256 depositedAmount, uint256 mintedShares);
}
