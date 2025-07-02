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
        MigratorDVV migratorDVV = MigratorDVV(0x0000003cE4397E957a5634f1402D29Ca5D239319);
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

        address[12] memory holders = [
            0x757dB7C1D65b1d3144E2AfB3dE8AA3D6Ee87594C,
            0xaCA98383f1262AFbA2b9702D763f6B3fA7288887,
            0xfB155533C76C877c6acc2C4b6D2341744F61B5f6,
            0x0C706Bd201903db654f748B824D4cFDE63EDb4c2,
            0xb867416A190C0d9050E941d4c19C7Ac77CEFa747,
            0xCfdc7f77c37268c14293ebD466768F6068D99461,
            0x77D0dce4286022aD5Ebd171F6e3a5D6Ac629F1AB,
            0xBb8311Ea9Ac8c1C9eFBc1A401B7e83927aee5b2B,
            0xBc334785d79836043A647E1EE686Bd36d6cF27c4,
            0x96E3c03358C8e39945eddEbAeac758389C215a26,
            0x357Db7aB93Eef87334f12Aa4D02bfaA548C27514,
            0xA19265bADD946329A8A8F84f25403E44Ab185aB8
        ];

        uint256[] memory balancesBefore = new uint256[](holders.length);
        for (uint256 i = 0; i < holders.length; i++) {
            balancesBefore[i] = IERC20(dvsteth).balanceOf(holders[i]);
            if (balancesBefore[i] == 0) {
                revert("Not a holder");
            }
        }

        // tx 2
        vm.startPrank(migratorDVV.PROXY_ADMIN_OWNER());
        ProxyAdmin(migratorDVV.PROXY_ADMIN()).transferOwnership(address(migratorDVV));
        migratorDVV.migrateDVV();
        migratorDVV.renounceOwnership();
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
        {
            uint256 valueAfter =
                IWSTETH(wsteth).getStETHByWstETH(wstethBalanceAfter) + wethBalanceAfter;
            assertApproxEqAbs(
                valueBefore, valueAfter + withdrawnValue, 1 wei, "Value mismatch after migration"
            ); // roundings due to mellow-lrt evaluation logic with wsteth
        }
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

        for (uint256 i = 0; i < holders.length; i++) {
            uint256 balanceAfter = IERC20(dvsteth).balanceOf(holders[i]);
            assertEq(balanceAfter, balancesBefore[i], "Holder balance mismatch after migration");
        }

        assertTrue(
            ProxyAdmin(migratorDVV.PROXY_ADMIN()).owner() == migratorDVV.PROXY_ADMIN_OWNER(),
            "ProxyAdmin owner mismatch after migration"
        );

        assertEq(
            migratorDVV.DVSTETH(),
            0x5E362eb2c0706Bd1d134689eC75176018385430B,
            "DVSTETH address mismatch after migration"
        );
        assertEq(
            migratorDVV.PROXY_ADMIN_OWNER(),
            0x81698f87C6482bF1ce9bFcfC0F103C4A0Adf0Af0,
            "PROXY_ADMIN_OWNER address mismatch after migration"
        );
        assertEq(
            migratorDVV.ADMIN(),
            0x9437B2a8cF3b69D782a61f9814baAbc172f72003,
            "ADMIN address mismatch after migration"
        );
        assertEq(
            migratorDVV.PROXY_ADMIN(),
            0x8E6C80c41450D3fA7B1Fd0196676b99Bfb34bF48,
            "PROXY_ADMIN address mismatch after migration"
        );
        assertEq(
            migratorDVV.DEPOSIT_WRAPPER(),
            0xfD4a4922d1AFe70000Ce0Ec6806454e78256504e,
            "DEPOSIT_WRAPPER address mismatch after migration"
        );
        assertEq(
            migratorDVV.SIMPLE_DVT_STAKING_STRATEGY(),
            0x078b1C03d14652bfeeDFadf7985fdf2D8a2e8108,
            "SIMPLE_DVT_STAKING_STRATEGY address mismatch after migration"
        );
    }
}
