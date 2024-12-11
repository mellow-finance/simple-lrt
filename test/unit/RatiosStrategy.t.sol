// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

contract Unit is BaseTest {
    function testConstructor() external {
        RatiosStrategy c = new RatiosStrategy();
        assertNotEq(address(c), address(0));
    }

    function testSetRatios() external {
        RatiosStrategy c = new RatiosStrategy();
        assertNotEq(address(c), address(0));
    }
}
