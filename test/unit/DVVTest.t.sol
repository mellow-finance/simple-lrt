// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/interfaces/tokens/IWSTETH.sol";
import "../../src/utils/MigratorDVV.sol";
import "../../src/vaults/DVV.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "forge-std/Test.sol";

contract Unit is Test {
    address public immutable weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public immutable wsteth = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    function testDVVMigration() external {
        DVV dvvSingleton = new DVV();
        MigratorDVV migratorDVV = new MigratorDVV(address(dvvSingleton), 11679 ether);

        // tx 1
        vm.startPrank(migratorDVV.ADMIN());
        IAccessControl(migratorDVV.SIMPLE_DVT_STAKING_STRATEGY()).grantRole(
            keccak256("admin_delegate"), migratorDVV.ADMIN()
        );
        IAccessControl(migratorDVV.SIMPLE_DVT_STAKING_STRATEGY()).grantRole(
            keccak256("operator"), address(migratorDVV)
        );
        vm.stopPrank();

        address dvsteth = migratorDVV.DVSTETH();
        uint256 wstethBalanceBefore = IERC20(wsteth).balanceOf(dvsteth);
        uint256 wethBalanceBefore = IERC20(weth).balanceOf(dvsteth);
        uint256 totalSupplyBefore = IERC20(dvsteth).totalSupply();
        uint256 selfBalanceBefore = IERC20(dvsteth).balanceOf(dvsteth);

        // tx 2
        vm.startPrank(migratorDVV.PROXY_ADMIN_OWNER());
        ProxyAdmin(migratorDVV.PROXY_ADMIN()).transferOwnership(address(migratorDVV));
        migratorDVV.migrateDVV();
        vm.stopPrank();

        uint256 wstethBalanceAfter = IERC20(wsteth).balanceOf(dvsteth);
        uint256 wethBalanceAfter = IERC20(weth).balanceOf(dvsteth);
        uint256 totalSupplyAfter = IERC20(dvsteth).totalSupply();
        uint256 selfBalanceAfter = IERC20(dvsteth).balanceOf(dvsteth);

        assertEq(
            totalSupplyBefore,
            totalSupplyAfter + selfBalanceBefore - selfBalanceAfter,
            "Total supply mismatch after migration"
        );
        uint256 valueBefore =
            IWSTETH(wsteth).getStETHByWstETH(wstethBalanceBefore) + wethBalanceBefore;
        uint256 withdrawnValue =
            Math.mulDiv(selfBalanceBefore - selfBalanceAfter, valueBefore, totalSupplyBefore);
        uint256 valueAfter = IWSTETH(wsteth).getStETHByWstETH(wstethBalanceAfter) + wethBalanceAfter;
        assertApproxEqAbs(
            valueBefore, valueAfter + withdrawnValue, 1 wei, "Value mismatch after migration"
        ); // roundings due to mellow-lrt evaluation logic with wsteth

        assertEq(wethBalanceAfter, 0, "WETH balance mismatch after migration");
        assertEq(
            IERC4626(dvsteth).totalAssets(),
            wstethBalanceAfter,
            "DVV total assets mismatch after migration"
        );

        assertEq(
            IERC4626(dvsteth).name(),
            "Decentralized Validator Token",
            "DVV name mismatch after migration"
        );
        assertEq(IERC4626(dvsteth).symbol(), "DVstETH", "DVV symbol mismatch after migration");
    }
}
