// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./Imports.sol";

abstract contract BaseTest is Test {
    SymbioticHelper internal immutable symbioticHelper;

    address public wstethSymbioticCollateral = Constants.HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL;

    function fillCollateral() public {
        IDefaultCollateral c = IDefaultCollateral(wstethSymbioticCollateral);
        address t = c.asset();
        uint256 s = c.totalSupply();
        uint256 l = c.limit();
        uint256 a = l - s;
        deal(t, address(this), a);
        IERC20(t).approve(address(c), a);
        c.deposit(address(this), a);
    }

    constructor() {
        symbioticHelper = new SymbioticHelper();
    }

    function test() private pure {}
}
