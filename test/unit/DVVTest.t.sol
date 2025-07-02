// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/interfaces/tokens/IWSTETH.sol";
import "../../src/utils/MigratorDVV.sol";

import "../../src/utils/WhitelistedEthWrapper.sol";
import "../../src/vaults/DVV.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "forge-std/Test.sol";

contract Unit is Test {
    address public immutable weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public immutable wsteth = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    function testDVVMigration() external {
        MigratorDVV migratorDVV = MigratorDVV(0x0000003cE4397E957a5634f1402D29Ca5D239319);
        {
            DVV dvv = DVV(payable(migratorDVV.DVSTETH()));
            for (uint256 i = 1; i <= 10; i++) {
                address user = vm.createWallet(string.concat("random_user_", vm.toString(i))).addr;
                vm.startPrank(user);
                uint256 amount = i * 1 ether;
                uint256 totalAssetsBefore = dvv.totalAssets();
                uint256 totalSupplyBefore = dvv.totalSupply();
                deal(user, amount);
                WhitelistedEthWrapper wrapper =
                    WhitelistedEthWrapper(payable(migratorDVV.DEPOSIT_WRAPPER()));
                uint256 expectedValue = IWSTETH(wsteth).getWstETHByStETH(amount);
                uint256 expectedShares = dvv.previewDeposit(expectedValue);
                uint256 shares = wrapper.deposit{value: amount}(
                    wrapper.ETH(), amount, address(dvv), user, address(0)
                );

                assertEq(
                    totalAssetsBefore + expectedValue,
                    dvv.totalAssets(),
                    "Total assets mismatch after deposit"
                );
                assertEq(
                    totalSupplyBefore + expectedShares,
                    dvv.totalSupply(),
                    "Total supply mismatch after deposit"
                );

                assertEq(shares, expectedShares, "Shares mismatch after deposit");
                assertEq(dvv.balanceOf(user), shares, "Balance mismatch after deposit");
                uint256 assets = dvv.redeem(shares, user, user);
                assertApproxEqAbs(assets, expectedValue, 1 wei, "Assets mismatch after redeem");

                assertEq(dvv.balanceOf(user), 0, "Balance mismatch after redeem");
                assertApproxEqAbs(
                    dvv.totalAssets(),
                    totalAssetsBefore,
                    1 wei,
                    "Total assets mismatch after redeem"
                );
                assertEq(dvv.totalSupply(), totalSupplyBefore, "Total supply mismatch after redeem");

                vm.stopPrank();
            }
        }

        {
            DVV dvv = DVV(payable(migratorDVV.DVSTETH()));
            for (uint256 i = 1; i <= 10; i++) {
                address user = vm.createWallet(string.concat("random_user_", vm.toString(i))).addr;
                vm.startPrank(user);
                uint256 amount = i * 1 ether;
                uint256 totalAssetsBefore = dvv.totalAssets();
                uint256 totalSupplyBefore = dvv.totalSupply();
                WhitelistedEthWrapper wrapper =
                    WhitelistedEthWrapper(payable(migratorDVV.DEPOSIT_WRAPPER()));
                deal(weth, user, amount);
                IERC20(weth).approve(address(wrapper), amount);
                uint256 expectedValue = IWSTETH(wsteth).getWstETHByStETH(amount);
                uint256 expectedShares = dvv.previewDeposit(expectedValue);
                uint256 shares =
                    wrapper.deposit(wrapper.WETH(), amount, address(dvv), user, address(0));

                assertEq(
                    totalAssetsBefore + expectedValue,
                    dvv.totalAssets(),
                    "Total assets mismatch after deposit"
                );
                assertEq(
                    totalSupplyBefore + expectedShares,
                    dvv.totalSupply(),
                    "Total supply mismatch after deposit"
                );

                assertEq(shares, expectedShares, "Shares mismatch after deposit");
                assertEq(dvv.balanceOf(user), shares, "Balance mismatch after deposit");
                uint256 assets = dvv.redeem(shares, user, user);
                assertApproxEqAbs(assets, expectedValue, 1 wei, "Assets mismatch after redeem");

                assertEq(dvv.balanceOf(user), 0, "Balance mismatch after redeem");
                assertApproxEqAbs(
                    dvv.totalAssets(),
                    totalAssetsBefore,
                    1 wei,
                    "Total assets mismatch after redeem"
                );
                assertEq(dvv.totalSupply(), totalSupplyBefore, "Total supply mismatch after redeem");

                vm.stopPrank();
            }
        }
    }
}
