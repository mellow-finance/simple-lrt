// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

contract Unit is BaseTest {
    using RandomLib for RandomLib.Storage;

    function testConstructor() external {
        vm.expectRevert();
        new SymbioticWithdrawalQueue(address(0), address(0), address(0));

        (address symbioticVault,,,) =
            symbioticHelper.createDefaultSymbioticVault(Constants.WSTETH());
        assertNotEq(
            address(0),
            address(new SymbioticWithdrawalQueue(address(0), symbioticVault, address(0)))
        );
    }

    function testRegularCreationSymbioticWithdrawalQueue() external {
        address vault = rnd.randAddress();
        SymbioticAdapter adapter = new SymbioticAdapter(vault, address(new Claimer()));
        (address symbioticVault,,,) =
            symbioticHelper.createDefaultSymbioticVault(Constants.WSTETH());
        vm.startPrank(vault);
        ISymbioticWithdrawalQueue withdrawalQueue =
            ISymbioticWithdrawalQueue(adapter.handleVault(symbioticVault));
        assertNotEq(address(withdrawalQueue), address(0));
    }

    function testSymbioticWithdrawalQueue() external {
        address vaultAdmin = rnd.randAddress();
        (MultiVault vault,,, address symbioticVault) =
            createDefaultMultiVaultWithSymbioticVault(vaultAdmin);
        address user = rnd.randAddress();
        vm.startPrank(user);
        deal(Constants.WSTETH(), user, 1 ether);
        IERC20(Constants.WSTETH()).approve(address(vault), type(uint256).max);
        vault.deposit(1 ether, user);
        vault.redeem(vault.balanceOf(user), user, user);
        vm.stopPrank();
        ISymbioticWithdrawalQueue withdrawalQueue =
            ISymbioticWithdrawalQueue(vault.subvaultAt(0).withdrawalQueue);

        assertEq(ISymbioticVault(symbioticVault).activeBalanceOf(address(withdrawalQueue)), 0);
        assertEq(
            ISymbioticVault(symbioticVault).slashableBalanceOf(address(withdrawalQueue)), 1 ether
        );
    }
}
