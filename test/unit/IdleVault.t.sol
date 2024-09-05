// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

contract Unit is BaseTest {
    address wsteth = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;
    address steth = 0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034;
    address weth = 0x94373a4919B3240D86eA41593D5eBa789FEF3848;

    function testInitialize() external {
        IdleVault vault = new IdleVault();
        address token = wsteth;
        address admin = makeAddr("admin");
        IIdleVault.InitParams memory initParams = IIdleVault.InitParams({
            asset: token,
            limit: 100 ether,
            depositPause: false,
            withdrawalPause: false,
            depositWhitelist: false,
            admin: admin,
            name: "IdleVault",
            symbol: "IDLE"
        });

        vm.recordLogs();
        vault.initialize(initParams);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(vault.decimals(), 18);
        assertTrue(vault.hasRole(bytes32(0), admin));
        assertEq(logs.length, 7);
        assertEq(logs[5].emitter, address(vault));
        assertEq(
            logs[5].topics[0],
            keccak256(
                "IdleVaultInitialized((address,uint256,bool,bool,bool,address,string,string),uint256)"
            )
        );

        vm.expectRevert();
        vault.initialize(initParams);
    }
}
