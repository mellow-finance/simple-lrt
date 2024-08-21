// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

contract Unit is BaseTest {
    address wsteth = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;
    address steth = 0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034;
    address weth = 0x94373a4919B3240D86eA41593D5eBa789FEF3848;

    function testEthDeposit() external {
        IdleVault vault = new IdleVault();
        address token = wsteth;
        vault.initialize(
            IIdleVault.InitParams({
                asset: token,
                limit: 100 ether,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                admin: makeAddr("admin"),
                name: "IdleVault",
                symbol: "IDLE"
            })
        );

        assertEq(vault.decimals(), 18);
    }
}
