// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import "../src/MellowSymbioticVotesVault.sol";
import "../src/MellowSymbioticVotesVaultFactory.sol";

contract Tests is Test {
    function test() external {
        MellowSymbioticVotesVault singleton =
            new MellowSymbioticVotesVault("MellowSymbioticVotesVault", 1);
        MellowSymbioticVotesVaultFactory factory =
            new MellowSymbioticVotesVaultFactory(address(singleton));
    }
}
