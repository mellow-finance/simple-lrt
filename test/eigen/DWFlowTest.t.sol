// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./EigenBaseTest.sol";
import "src/interfaces/tokens/ISTETH.sol";

contract DWFlowTest is EigenBaseTest {
    function testDeposit() public {
        vm.deal(user, 10 ether);

        vm.startPrank(user);

        ISTETH(underlyingTokenAddress).submit{value: 1 ether}(user);
        console2.log("user balance0: ", IERC20(underlyingTokenAddress).balanceOf(user));
        IERC20(underlyingTokenAddress).approve(address(mellowEigenLayerVault), 1 ether);

        console2.log("user preview : ", mellowEigenLayerVault.previewDeposit(1 ether));
        mellowEigenLayerVault.deposit(1 ether, user);
        console2.log("user balance1: ", IERC20(underlyingTokenAddress).balanceOf(user));

        vm.stopPrank();

        console2.log("user vaultbal: ", mellowEigenLayerVault.balanceOf(user));
        console2.log("user withdraw: ", mellowEigenLayerVault.maxWithdraw(user));
    }

    function testDepositWithdraw() public {
        vm.deal(user, 10 ether);

        uint256 minWithdrawalDelayBlocks = IDelegationManager(
            mellowEigenLayerVault.eigenLayerDelegationManager()
        ).minWithdrawalDelayBlocks();
        vm.startPrank(user);

        ISTETH(underlyingTokenAddress).submit{value: 1 ether}(user);
        IERC20(underlyingTokenAddress).approve(address(mellowEigenLayerVault), 1 ether);

        mellowEigenLayerVault.deposit(1 ether, user);

        console2.log("user vault balance0: ", mellowEigenLayerVault.balanceOf(user));
        console2.log("user stETH balance0: ", IERC20(underlyingTokenAddress).balanceOf(user));

        uint256 maxAssets = mellowEigenLayerVault.maxWithdraw(user);
        mellowEigenLayerVault.withdraw(maxAssets, user, user);

        console2.log("user vault balance1: ", mellowEigenLayerVault.balanceOf(user));

        vm.roll(block.number + minWithdrawalDelayBlocks);
        
        uint256 gas0 = gasleft();
        mellowEigenLayerVault.claim(user, user);
        console2.log("clam gas", gas0 - gasleft());
        vm.expectRevert("Vault: no active withdrawals");
        mellowEigenLayerVault.claim(user, user);

        console2.log("user stETH balance1: ", IERC20(underlyingTokenAddress).balanceOf(user));

        vm.stopPrank();
    }
}
