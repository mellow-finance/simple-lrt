// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";
import "../mocks/MockEigenLayerFarm.sol";

contract Unit is BaseTest {
    using RandomLib for RandomLib.Storage;

    function testEigenLayerAdapter() external {
        MultiVault vault;
        {
            TransparentUpgradeableProxy c_ = new TransparentUpgradeableProxy(
                address(new MultiVault("test", 1)), vm.createWallet("proxyAdmin").addr, new bytes(0)
            );
            vault = MultiVault(address(c_));
        }
        address isolatedEigenLayerWstETHVault = address(new IsolatedEigenLayerVault());
        IsolatedEigenLayerVaultFactory factory = new IsolatedEigenLayerVaultFactory(
            Constants.HOLESKY_EL_DELEGATION_MANAGER,
            isolatedEigenLayerWstETHVault,
            address(
                new EigenLayerWithdrawalQueue(
                    address(new Claimer()), Constants.HOLESKY_EL_DELEGATION_MANAGER
                )
            ),
            vm.createWallet("proxyAdmin").addr
        );
        IEigenLayerAdapter eigenLayerAdapter = new EigenLayerAdapter(
            address(factory),
            address(vault),
            IStrategyManager(Constants.HOLESKY_EL_STRATEGY_MANAGER),
            IRewardsCoordinator(Constants.HOLESKY_EL_REWARDS_COORDINATOR)
        );

        vm.expectRevert("Delegate call only");
        eigenLayerAdapter.pushRewards(address(0), new bytes(0), new bytes(0));

        vm.expectRevert("Delegate call only");
        eigenLayerAdapter.withdraw(address(0), address(0), address(0), 0, address(0));

        vm.expectRevert("Delegate call only");
        eigenLayerAdapter.deposit(address(0), 0);

        vm.expectRevert("EigenLayerAdapter: invalid isolated vault owner");
        eigenLayerAdapter.handleVault(address(0));
    }

    function testMaxDeposit() external {
        address vaultAdmin = rnd.randAddress();
        (MultiVault vault, EigenLayerAdapter eigenLayerAdapter,, address eigenLayerVault) =
            createDefaultMultiVaultWithEigenVault(vaultAdmin);
        IEigenLayerWithdrawalQueue withdrawalQueue =
            EigenLayerWithdrawalQueue(vault.subvaultAt(0).withdrawalQueue);

        uint256 maxDeposit = eigenLayerAdapter.maxDeposit(eigenLayerVault);
        assertEq(
            maxDeposit,
            type(uint256).max
                - IERC20(EigenLayerAdapter(eigenLayerAdapter).assetOf(eigenLayerVault)).balanceOf(
                    withdrawalQueue.strategy()
                ),
            "maxDeposit"
        );

        address user = rnd.randAddress();
        uint256 amount = 100 ether;
        deal(Constants.WSTETH(), user, amount);

        vm.startPrank(user);
        amount = IWSTETH(Constants.WSTETH()).unwrap(amount);
        IERC20(Constants.STETH()).approve(address(vault), amount);
        vault.deposit(amount, user);
        vault.withdraw(amount / 2, user, user);
        vm.stopPrank();

        vm.expectRevert("EigenLayerWithdrawalQueue: not yet forcibly unstaked");
        withdrawalQueue.shutdown(uint32(block.number), 0);

        uint256 shares =
            IStrategy(withdrawalQueue.strategy()).shares(withdrawalQueue.isolatedVault());

        vm.startPrank(0xbF8a8B0d0450c8812ADDf04E1BcB7BfBA0E82937);
        IDelegationManager(Constants.HOLESKY_EL_DELEGATION_MANAGER).undelegate(eigenLayerVault);
        vm.stopPrank();
        withdrawalQueue.shutdown(uint32(block.number), shares);

        maxDeposit = eigenLayerAdapter.maxDeposit(eigenLayerVault);
        assertEq(maxDeposit, 0, "maxDeposit not zero");
    }

    function testStakedAt() external {
        address vaultAdmin = rnd.randAddress();
        (, EigenLayerAdapter eigenLayerAdapter,, address eigenLayerVault) =
            createDefaultMultiVaultWithEigenVault(vaultAdmin);

        vm.startPrank(0xbF8a8B0d0450c8812ADDf04E1BcB7BfBA0E82937);
        IDelegationManager(Constants.HOLESKY_EL_DELEGATION_MANAGER).undelegate(eigenLayerVault);
        vm.stopPrank();

        vm.expectRevert("EigenLayerAdapter: isolated vault is neither delegated nor shut down");
        eigenLayerAdapter.stakedAt(eigenLayerVault);
    }
}
