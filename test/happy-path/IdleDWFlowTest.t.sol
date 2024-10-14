// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

contract Integration is BaseTest {
    /*
        forge test -vvvv  --match-path ./test/DWFlowTest.t.sol --fork-url $(grep HOLESKY_RPC .env | cut -d '=' -f2,3,4,5)  --fork-block-number 2160000
    */

    address admin = makeAddr("admin");
    address user = makeAddr("user");
    address limitIncreaser = makeAddr("limitIncreaser");

    function testIdle() external {
        require(block.chainid == 17000, "This test can only be run on the Holesky testnet");

        IdleVault vault = new IdleVault();
        address token = Constants.WSTETH();
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

        EthWrapper wrapper = new EthWrapper(Constants.WETH(), Constants.WSTETH(), Constants.STETH());

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
