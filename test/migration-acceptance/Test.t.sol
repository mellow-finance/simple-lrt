// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./AcceptanceTestRunner.sol";
import "forge-std/Test.sol";

contract Acceptance is AcceptanceTestRunner, Test {
    function migrateAndCheck(address vault, address curator) public {
        address proxyAdmin = getProxyAdmin(vault);

        (,, uint256 stageTimestamp) = migrator.migrations(proxyAdmin);

        vm.startPrank(VAULT_PROXY_ADMIN);
        if (stageTimestamp == 0 && !migrator.isEntity(vault)) {
            State memory before_ = loadSimpleLRTState(vault);

            // tx 1
            migrator.stageMigration(ProxyAdmin(proxyAdmin), vault);
            skip(4 hours);

            // tx 2
            ProxyAdmin(proxyAdmin).transferOwnership(address(migrator));
            migrator.executeMigration(ProxyAdmin(proxyAdmin), VAULT_ADMIN);

            State memory after_ = loadMultiVaultState(vault);
            validateState(vault, curator, before_, after_);
        } else if (stageTimestamp != 0 && !migrator.isEntity(vault)) {
            State memory before_ = loadSimpleLRTState(vault);
            skip(stageTimestamp - block.timestamp);

            // tx 2
            ProxyAdmin(proxyAdmin).transferOwnership(address(migrator));
            migrator.executeMigration(ProxyAdmin(proxyAdmin), VAULT_ADMIN);

            State memory after_ = loadMultiVaultState(vault);
            validateState(vault, curator, before_, after_);
        } else if (stageTimestamp == 0 && migrator.isEntity(vault)) {
            State memory state_ = loadMultiVaultState(vault);
            validateState(vault, curator, state_, state_);
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
            0x4f3Cc6359364004b245ad5bE36E6ad4e805dC961,
            0x49cd586dd9BA227Be9654C735A659a1dB08232a9,
            0x82dc3260f599f4fC4307209A1122B6eAa007163b,
            0x375A8eE22280076610cA2B4348d37cB1bEEBeba0,
            0xd6E09a5e6D719d1c881579C9C8670a210437931b,
            0x8c9532a60E0E7C6BbD2B2c1303F63aCE1c3E9811,
            0xBEEF69Ac7870777598A04B2bd4771c71212E6aBc,
            0x84631c0d0081FDe56DeB72F6DE77abBbF6A9f93a,
            0x5fD13359Ba15A84B76f7F87568309040176167cd,
            0x7a4EffD87C2f3C55CA251080b1343b605f327E3a,
            0xcC36e5272c422BEE9A8144cD2493Ac472082eBaD,
            0x7b31F008c48EFb65da78eA0f255EE424af855249,
            0xB908c9FE885369643adB5FBA4407d52bD726c72d,
            0x24183535a24CF0272841B05047A26e200fFAB696
        ];

        address[14] memory curators = [
            0x013B33aAdae8aBdc7c2B1529BB28a37299D6EadE,
            0x7d69615DDD0207ffaD3D89493f44362B471Cfc5C,
            0x5dbb14865609574ABE0d701B1E23E11dF8312548,
            0x323B1370eC7D17D0c70b2CbebE052b9ed0d8A289,
            0xD36BE1D5d02ffBFe7F9640C3757999864BB84979,
            0x6e5CaD73D00Bc8340f38afb61Fc5E34f7193F599,
            0x2E93913A796a6C6b2bB76F41690E78a2E206Be54,
            0xE86399fE6d7007FdEcb08A2ee1434Ee677a04433,
            0xA1E38210B06A05882a7e7Bfe167Cd67F07FA234A,
            0xE86399fE6d7007FdEcb08A2ee1434Ee677a04433,
            0x903D4E20a3b70D6aE54E1Cb91Fec2E661E2af3A5,
            0xf9d20f02aB533ac6F990C9D96B595651d83b4b92,
            0xD1f59ba974E828dF68cB2592C16b967B637cB4e4,
            0xE3a148b25Cca54ECCBD3A4aB01e235D154f03eFa
        ];

        for (uint256 i = 0; i < vaults.length; i++) {
            migrateAndCheck(vaults[i], curators[i]);
        }
    }
}
