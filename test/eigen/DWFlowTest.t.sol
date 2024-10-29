// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./EigenBaseTest.sol";
import "src/interfaces/tokens/ISTETH.sol";

contract DWFlowTest is EigenBaseTest {
    function testDeposit() public {
        vm.startPrank(user);

        ISTETH(underlyingTokenAddress).submit{value: 1 ether}(user);
        IERC20(underlyingTokenAddress).approve(address(mellowEigenLayerVault), 1 ether);

        uint256 previewDeposit = mellowEigenLayerVault.previewDeposit(1 ether);
        mellowEigenLayerVault.deposit(1 ether, user);

        vm.stopPrank();

        uint256 share = mellowEigenLayerVault.balanceOf(user);
        assertApproxEqAbs(previewDeposit, share, 1);
    }

    function testDepositWithdraw() public {
        uint256 minWithdrawalDelayBlocks = IDelegationManager(
            mellowEigenLayerVault.eigenLayerDelegationManager()
        ).minWithdrawalDelayBlocks();
        vm.startPrank(user);

        ISTETH(underlyingTokenAddress).submit{value: 1 ether}(user);
        IERC20(underlyingTokenAddress).approve(address(mellowEigenLayerVault), 1 ether);
        uint256 assetsBalance0 = IERC20(underlyingTokenAddress).balanceOf(user);

        mellowEigenLayerVault.deposit(1 ether, user);

        uint256 shares0 = mellowEigenLayerVault.balanceOf(user);

        uint256 maxAssets = mellowEigenLayerVault.maxWithdraw(user);
        uint256 withdrawShares = mellowEigenLayerVault.withdraw(maxAssets, user, user);

        assertApproxEqAbs(maxAssets, assetsBalance0, 1);
        assertApproxEqAbs(withdrawShares, shares0, 1);

        uint256 pendingAssets = mellowEigenLayerVault.pendingAssetsOf(user);
        assertApproxEqAbs(pendingAssets, maxAssets, 1);
        assertEq(mellowEigenLayerVault.claimableAssetsOf(user), 0);

        vm.roll(block.number + minWithdrawalDelayBlocks);
        uint256 claimableAssets = mellowEigenLayerVault.claimableAssetsOf(user);
        assertApproxEqAbs(claimableAssets, pendingAssets, 1);

        mellowEigenLayerVault.claim(user, user);
        vm.expectRevert("Vault: no active withdrawals");
        mellowEigenLayerVault.claim(user, user);

        uint256 assetsBalance1 = IERC20(underlyingTokenAddress).balanceOf(user);
        assertApproxEqAbs(claimableAssets, assetsBalance1, 2);

        uint256 shares1 = mellowEigenLayerVault.balanceOf(user);
        assertApproxEqAbs(shares1, 0, 1);
        vm.stopPrank();
    }

    function testWithdrawQueueLimit() public {
        uint256 minWithdrawalDelayBlocks = IDelegationManager(
            mellowEigenLayerVault.eigenLayerDelegationManager()
        ).minWithdrawalDelayBlocks();
        uint256 claimWithdrawalsMax = mellowEigenLayerVault.eigenLayerClaimWithdrawalsMax();
        vm.startPrank(user);

        ISTETH(underlyingTokenAddress).submit{value: 1 ether + 1}(user);
        IERC20(underlyingTokenAddress).approve(address(mellowEigenLayerVault), 1 ether + 1);
        uint256 assetsBalance0 = IERC20(underlyingTokenAddress).balanceOf(user);

        mellowEigenLayerVault.deposit(1 ether + 1, user);

        uint256 shares0 = mellowEigenLayerVault.balanceOf(user);

        uint256 maxAssets = mellowEigenLayerVault.maxWithdraw(user);
        assertApproxEqAbs(maxAssets, assetsBalance0, 1);

        for (uint256 i = 0; i < claimWithdrawalsMax; i++) {
            uint256 withdrawShares =
                mellowEigenLayerVault.withdraw(maxAssets / claimWithdrawalsMax, user, user);
            assertApproxEqAbs(withdrawShares, shares0 / claimWithdrawalsMax, 1);
        }

        uint256 pendingAssets = mellowEigenLayerVault.pendingAssetsOf(user);
        assertApproxEqAbs(pendingAssets, maxAssets, claimWithdrawalsMax);
        assertEq(mellowEigenLayerVault.claimableAssetsOf(user), 0);

        maxAssets = mellowEigenLayerVault.maxWithdraw(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("ERC4626ExceededMaxWithdraw(address,uint256,uint256)")),
                user,
                maxAssets + 1,
                maxAssets
            )
        );
        mellowEigenLayerVault.withdraw(maxAssets + 1, user, user);

        vm.expectRevert("Vault: withdrawal queue size limit is reached");
        mellowEigenLayerVault.withdraw(maxAssets, user, user);

        vm.roll(block.number + minWithdrawalDelayBlocks);
        uint256 claimableAssets = mellowEigenLayerVault.claimableAssetsOf(user);
        assertApproxEqAbs(claimableAssets, pendingAssets, 1);

        mellowEigenLayerVault.claim(user, user);

        uint256 assetsBalance1 = IERC20(underlyingTokenAddress).balanceOf(user);
        assertApproxEqAbs(claimableAssets, assetsBalance1, 2 * claimWithdrawalsMax);

        uint256 shares1 = mellowEigenLayerVault.balanceOf(user);
        assertApproxEqAbs(shares1, 0, claimWithdrawalsMax);
        vm.stopPrank();
    }

    function testDepositFuzz(uint256 depositAmount) public {
        vm.assume(depositAmount > 10 ** 10);
        vm.assume(depositAmount < 1 ether);

        vm.startPrank(user);
        assertEq(mellowEigenLayerVault.balanceOf(user), 0);

        ISTETH(underlyingTokenAddress).submit{value: depositAmount}(user);
        IERC20(underlyingTokenAddress).approve(address(mellowEigenLayerVault), depositAmount);

        uint256 previewDeposit = mellowEigenLayerVault.previewDeposit(depositAmount);
        mellowEigenLayerVault.deposit(depositAmount, user);

        vm.stopPrank();

        uint256 share = mellowEigenLayerVault.balanceOf(user);
        assertEq(previewDeposit, share);
    }

    function testDepositSequenceWithdrawFuzz(uint256[100] calldata depositAmount) public {
        uint256 totalDeposited;
        for (uint256 i = 0; i < depositAmount.length; i++) {
            if (
                depositAmount[i] < 10 ** 6 || depositAmount[i] > 10 ether
                    || depositAmount[i] > user.balance
            ) {
                continue;
            }

            vm.startPrank(user);
            uint256 shareBefore = mellowEigenLayerVault.balanceOf(user);

            ISTETH(underlyingTokenAddress).submit{value: depositAmount[i]}(user);
            IERC20(underlyingTokenAddress).approve(address(mellowEigenLayerVault), depositAmount[i]);

            uint256 previewDeposit = mellowEigenLayerVault.previewDeposit(depositAmount[i]);
            mellowEigenLayerVault.deposit(depositAmount[i], user);

            vm.stopPrank();

            uint256 shareAfter = mellowEigenLayerVault.balanceOf(user);
            assertEq(previewDeposit, shareAfter - shareBefore);
            totalDeposited += depositAmount[i];
        }
        uint256 maxAssets = mellowEigenLayerVault.maxWithdraw(user);
        assertApproxEqAbs(maxAssets, totalDeposited, 100);

        vm.startPrank(user);
        uint256 shares = mellowEigenLayerVault.balanceOf(user);
        uint256 withdrawShares = mellowEigenLayerVault.withdraw(maxAssets, user, user);
        vm.stopPrank();
        assertApproxEqAbs(withdrawShares, shares, 1);
    }
}
