// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./Imports.sol";

contract BaseTest is Test {
    SymbioticHelper internal immutable symbioticHelper;

    address public wstethSymbioticCollateral = 0x23E98253F372Ee29910e22986fe75Bb287b011fC;

    constructor() {
        // totalSupply -> limit for DefaultCollateral
        {
            IDefaultCollateral c = IDefaultCollateral(wstethSymbioticCollateral);
            address t = c.asset();
            uint256 s = c.totalSupply();
            uint256 l = c.limit();
            uint256 a = l - s;
            deal(t, address(this), a);
            IERC20(t).approve(address(c), a);
            c.deposit(address(this), a);
        }
        SymbioticContracts symbioticContracts = new SymbioticContracts();
        symbioticHelper = new SymbioticHelper(symbioticContracts);
    }

    function test() external pure {}
}
