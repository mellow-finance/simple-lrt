// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./Imports.sol";

contract BaseTest is Test {
    SymbioticHelper internal immutable symbioticHelper;

    constructor() {
        SymbioticContracts symbioticContracts = new SymbioticContracts();
        symbioticHelper = new SymbioticHelper(symbioticContracts);
    }

    function test() external pure {}
}
