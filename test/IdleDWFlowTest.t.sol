// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./Imports.sol";

contract Integration is Test {
    /*
        forge test -vvvv  --match-path ./test/DWFlowTest.t.sol --fork-url $(grep HOLESKY_RPC .env | cut -d '=' -f2,3,4,5)  --fork-block-number 2160000
    */

    address admin = makeAddr("admin");
    address user = makeAddr("user");
    address limitIncreaser = makeAddr("limitIncreaser");
    address wsteth = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;
    address steth = 0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034;
    address weth = 0x94373a4919B3240D86eA41593D5eBa789FEF3848;

    function testIdle() external {
        require(block.chainid == 17000, "This test can only be run on the Holesky testnet");

        IdleVault vault = new IdleVault();
        address token = wsteth;
        vault.initialize(
            IIdleVault.InitParams({
                asset: token,
                limit: 100 ether,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                admin: admin,
                name: "IdleVault",
                symbol: "IDLE"
            })
        );

        EthWrapper wrapper = new EthWrapper(weth, wsteth, steth);

        uint256 amount = 0.33 ether;
        uint256 n = 10;
        vm.startPrank(user);
        deal(token, user, amount * n);
        IERC20(token).approve(address(wrapper), amount * n);

        for (uint256 i = 0; i < n; i++) {
            wrapper.deposit(token, amount, address(vault), user, makeAddr("referrer"));
        }
        for (uint256 i = 0; i < n; i++) {
            vault.withdraw(amount, user, user);
        }

        vm.stopPrank();
    }
}
