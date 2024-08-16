// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import "../src/MellowSymbioticVaultFactory.sol";
import "../src/MellowSymbioticVotesVault.sol";

contract Tests is Test {
    function test() external {
        MellowSymbioticVotesVault singleton =
            new MellowSymbioticVotesVault("MellowSymbioticVotesVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));
    }
}
