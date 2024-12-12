// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";
import "../mocks/MockMultiVault.sol";

contract Unit is BaseTest {
    function testConstructor() external {
        RatiosStrategy c = new RatiosStrategy();
        assertNotEq(address(c), address(0));
    }

    function testSetRatios() external {
        RatiosStrategy c = new RatiosStrategy();
        assertNotEq(address(c), address(0));

        MockMultiVault vault = new MockMultiVault();

        vm.expectRevert("RatiosStrategy: forbidden");
        c.setRatios(address(vault), new address[](0), new IRatiosStrategy.Ratio[](0));
        vault.setFlag(true);

        vm.expectRevert("RatiosStrategy: invalid length");
        c.setRatios(address(vault), new address[](10), new IRatiosStrategy.Ratio[](9));

        {
            (uint64 minRatioD18, uint64 maxRatioD18) = c.ratios(address(vault), address(0));
            assertEq(minRatioD18, 0);
            assertEq(maxRatioD18, 0);
        }

        // {
        //     address[] memory subvaults =
        //     IRatiosStrategy.Ratio[] memory ratios = new IRatiosStrategy.Ratio[](1);
        //     ratios[0] = IRatiosStrategy.Ratio(1 ether / 3, 1 ether / 2);
        //     c.setRatios(address(vault), new address[](1), ratios);
        // }
    }
}
