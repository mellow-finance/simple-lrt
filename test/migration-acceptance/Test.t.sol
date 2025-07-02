// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./AcceptanceTestRunner.sol";
import "forge-std/Test.sol";

contract Acceptance is AcceptanceTestRunner, Test {
    function migrateAndCheck(address vault) public {
        address proxyAdmin = getProxyAdmin(vault);

        (,, uint256 stageTimestamp) = migrator.migrations(proxyAdmin);
        vm.startPrank(VAULT_PROXY_ADMIN);
        if (stageTimestamp == 0 && !migrator.isEntity(vault)) {
            migrator.stageMigration(ProxyAdmin(proxyAdmin), vault);
            skip(4 hours);
            ProxyAdmin(proxyAdmin).transferOwnership(address(migrator));
            State memory before_ = loadSimpleLRTState(vault);
            migrator.executeMigration(ProxyAdmin(proxyAdmin), VAULT_ADMIN);
            State memory after_ = loadMultiVaultState(vault);
            validateState(vault, before_, after_);
        } else if (stageTimestamp != 0 && !migrator.isEntity(vault)) {
            skip(stageTimestamp - block.timestamp);
            ProxyAdmin(proxyAdmin).transferOwnership(address(migrator));
            State memory before_ = loadSimpleLRTState(vault);
            migrator.executeMigration(ProxyAdmin(proxyAdmin), VAULT_ADMIN);
            State memory after_ = loadMultiVaultState(vault);
            validateState(vault, before_, after_);
        } else if (stageTimestamp == 0 && migrator.isEntity(vault)) {
            State memory state_ = loadMultiVaultState(vault);
            validateState(vault, state_, state_);
        } else {
            revert("Invalid migrator state");
        }
        vm.stopPrank();

        runUserFlow(vault);
    }

    function runUserFlow(address vault) public {
        MultiVault v = MultiVault(vault);
        for (uint256 i = 1; i <= 10; i++) {
            address user = vm.createWallet(string.concat("random-user-", vm.toString(i))).addr;
            vm.startPrank(user);
            uint256 amount = i * 1 ether;
            vm.deal(user, amount);
            Address.sendValue(payable(WSTETH), amount);
            uint256 balance = IERC20(WSTETH).balanceOf(user);
            IERC20(WSTETH).approve(address(v), balance);
            uint256 shares = v.deposit(balance, user);

            assertEq(v.balanceOf(user), shares, "User shares mismatch");

            v.redeem(shares, user, user);
            assertEq(v.balanceOf(user), 0, "User shares not redeemed");

            // due to 0 min/max ratio set for symbiotic subvault all such withdrawals will be instant
            assertApproxEqAbs(
                IERC20(WSTETH).balanceOf(user),
                balance,
                1 wei,
                "User WSTETH balance mismatch after redeem"
            );

            vm.stopPrank();
        }
    }

    function testMultiMigration() external {
        address[14] memory vaults = [
            // batch 1
            0x4f3Cc6359364004b245ad5bE36E6ad4e805dC961,
            0x49cd586dd9BA227Be9654C735A659a1dB08232a9,
            0x82dc3260f599f4fC4307209A1122B6eAa007163b,
            0x375A8eE22280076610cA2B4348d37cB1bEEBeba0,
            0xd6E09a5e6D719d1c881579C9C8670a210437931b,
            0x8c9532a60E0E7C6BbD2B2c1303F63aCE1c3E9811,
            // batch 2
            0xBEEF69Ac7870777598A04B2bd4771c71212E6aBc,
            0x84631c0d0081FDe56DeB72F6DE77abBbF6A9f93a,
            0x5fD13359Ba15A84B76f7F87568309040176167cd,
            0x7a4EffD87C2f3C55CA251080b1343b605f327E3a,
            0xcC36e5272c422BEE9A8144cD2493Ac472082eBaD,
            0x7b31F008c48EFb65da78eA0f255EE424af855249,
            0xB908c9FE885369643adB5FBA4407d52bD726c72d,
            0x24183535a24CF0272841B05047A26e200fFAB696
        ];

        for (uint256 i = 0; i < vaults.length; i++) {
            migrateAndCheck(vaults[i]);
        }
    }
}
