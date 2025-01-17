// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

contract Unit is BaseTest {
    using RandomLib for RandomLib.Storage;

    function testConstructor() external {
        address withdrawalQueue = address(
            new EigenLayerWithdrawalQueue(
                address(new Claimer()), Constants.HOLESKY_EL_DELEGATION_MANAGER
            )
        );

        require(withdrawalQueue != address(0));
    }

    function testLatestWithdrawableBlock() external {
        EigenLayerWithdrawalQueue withdrawalQueue = new EigenLayerWithdrawalQueue(
            address(new Claimer()), Constants.HOLESKY_EL_DELEGATION_MANAGER
        );
        uint256 latestWithdrawableBlock = withdrawalQueue.latestWithdrawableBlock();

        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = IStrategy(withdrawalQueue.strategy());
        require(
            latestWithdrawableBlock
                == block.number
                    - IDelegationManager(withdrawalQueue.delegation()).getWithdrawalDelay(strategies)
        );
    }

    function testInitialize() external {
        Claimer claimer = new Claimer();

        EigenLayerWithdrawalQueue withdrawalQueueSingleton =
            new EigenLayerWithdrawalQueue(address(claimer), Constants.HOLESKY_EL_DELEGATION_MANAGER);

        require(address(withdrawalQueueSingleton) != address(0));

        vm.expectRevert(); // InvalidInitialization()
        withdrawalQueueSingleton.initialize(address(1), address(2), address(3));

        address proxyAdmin = rnd.randAddress();
        new TransparentUpgradeableProxy{salt: bytes32(uint256(1))}(
            address(withdrawalQueueSingleton),
            proxyAdmin,
            abi.encodeCall(
                EigenLayerWithdrawalQueue.initialize, (address(1), address(2), address(3))
            )
        );
    }

    function testClaimableAssetsOf() external {
        address vaultAdmin = rnd.randAddress();
        (MultiVault vault,,,) = createDefaultMultiVaultWithEigenWstETHVault(vaultAdmin);
        IEigenLayerWithdrawalQueue withdrawalQueue =
            EigenLayerWstETHWithdrawalQueue(vault.subvaultAt(0).withdrawalQueue);

        address user0 = rnd.randAddress();
        address user1 = 0x0101010101010101010101010101010101010101; //rnd.randAddress();
        address user2 = 0x0202020202020202020202020202020202020202; //rnd.randAddress();

        uint256 amount1 = 100 ether;
        uint256 amount2 = 100 ether;
        deal(Constants.WSTETH(), user0, amount1);
        deal(Constants.WSTETH(), user1, amount1);
        deal(Constants.WSTETH(), user2, amount2);

        vm.startPrank(user0);
        IERC20(Constants.WSTETH()).approve(address(vault), amount1);
        vault.deposit(amount1, user0);
        vault.withdraw(amount1 / 2, user0, user0);
        vm.stopPrank();

        {
            vm.startPrank(user1);
            IERC20(Constants.WSTETH()).approve(address(vault), amount1);
            vault.deposit(amount1, user1);
            vault.withdraw(amount1 / 2, user1, user1);
            vm.stopPrank();

            assertEq(withdrawalQueue.claimableAssetsOf(user1), 0, "user1: claimableAssets");
            vm.roll(block.number + 10); // skip delay
            assertApproxEqAbs(
                withdrawalQueue.claimableAssetsOf(user1), amount1 / 2, 2, "user1: claimableAssets"
            );
        }
        {
            vm.startPrank(user2);
            IERC20(Constants.WSTETH()).approve(address(vault), amount2);
            vault.deposit(amount2, user2);
            vault.withdraw(amount2 / 2, user2, user2);
            vm.stopPrank();

            assertEq(withdrawalQueue.claimableAssetsOf(user2), 0, "user2: claimableAssets");
            vm.roll(block.number + 10); // skip delay
            assertApproxEqAbs(
                withdrawalQueue.claimableAssetsOf(user2), amount2 / 2, 2, "user2: claimableAssets"
            );
        }

        {
            vm.prank(user1);
            withdrawalQueue.claim(user1, user1, amount1 / 2);
            assertEq(withdrawalQueue.claimableAssetsOf(user1), 0, "user1: claimableAssets");
            assertApproxEqAbs(IERC20(Constants.WSTETH()).balanceOf(user1), amount1/2, 3, "user1: balance");
        }
        {
            vm.prank(user2);
            withdrawalQueue.claim(user2, user2, amount2 / 2);
            assertEq(withdrawalQueue.claimableAssetsOf(user2), 0, "user2: claimableAssets");
            assertApproxEqAbs(IERC20(Constants.WSTETH()).balanceOf(user2), amount2/2, 3, "user2: balance");
        }

        vm.prank(user1);
        vault.withdraw(amount1 / 2, user1, user1);
        assertEq(withdrawalQueue.claimableAssetsOf(user1), 0, "user1: claimableAssets");
        vm.roll(block.number + 10); // skip delay
        assertApproxEqAbs(
            withdrawalQueue.claimableAssetsOf(user1), amount1 / 2, 2, "user1: claimableAssets"
        );

        vm.prank(user2);
        vault.withdraw(amount2 / 2, user2, user2);
        assertEq(withdrawalQueue.claimableAssetsOf(user2), 0, "user2: claimableAssets");
        vm.roll(block.number + 10); // skip delay
        assertApproxEqAbs(
            withdrawalQueue.claimableAssetsOf(user2), amount2 / 2, 2, "user2: claimableAssets"
        );
        
        return;
    }

    function testClaimableAssetsOfFail() external {
        address vaultAdmin = rnd.randAddress();
        (MultiVault vault,,,) = createDefaultMultiVaultWithEigenWstETHVault(vaultAdmin);
        IEigenLayerWithdrawalQueue withdrawalQueue =
            EigenLayerWstETHWithdrawalQueue(vault.subvaultAt(0).withdrawalQueue);

        address user1 = 0x0101010101010101010101010101010101010101; //rnd.randAddress();
        address user2 = 0x0202020202020202020202020202020202020202; //rnd.randAddress();

        uint256 amount1 = 100 ether;
        uint256 amount2 = 10 ether;
        deal(Constants.WSTETH(), user1, amount1);
        deal(Constants.WSTETH(), user2, amount2);

        {
            vm.startPrank(user1);
            IERC20(Constants.WSTETH()).approve(address(vault), amount1);
            vault.deposit(amount1, user1);
            vault.withdraw(amount1 / 2, user1, user1);
            vm.stopPrank();

            assertEq(withdrawalQueue.claimableAssetsOf(user1), 0, "user1: claimableAssets");
            vm.roll(block.number + 10); // skip delay
            assertApproxEqAbs(
                withdrawalQueue.claimableAssetsOf(user1), amount1 / 2, 2, "user1: claimableAssets"
            );
        }
        {
            vm.startPrank(user2);
            IERC20(Constants.WSTETH()).approve(address(vault), amount2);
            vault.deposit(amount2, user2);
            vault.withdraw(amount2 / 2, user2, user2);
            vm.stopPrank();

            assertEq(withdrawalQueue.claimableAssetsOf(user2), 0, "user2: claimableAssets");
            vm.roll(block.number + 10); // skip delay
            assertApproxEqAbs(
                withdrawalQueue.claimableAssetsOf(user2), amount2 / 2, 2, "user2: claimableAssets"
            );
        }

        {
            vm.prank(user1);
            withdrawalQueue.claim(user1, user1, amount1 / 2);
            assertEq(withdrawalQueue.claimableAssetsOf(user1), 0, "user1: claimableAssets");
            assertApproxEqAbs(IERC20(Constants.WSTETH()).balanceOf(user1), amount1/2, 3, "user1: balance");
        }
        {
            vm.prank(user2);
            withdrawalQueue.claim(user2, user2, amount2 / 2);
            assertEq(withdrawalQueue.claimableAssetsOf(user2), 0, "user2: claimableAssets");
            assertApproxEqAbs(IERC20(Constants.WSTETH()).balanceOf(user2), amount2/2, 3, "user2: balance");
        }

        {  // block 1
            vm.prank(user1);
            vault.withdraw(amount1 / 2, user1, user1);
            assertEq(withdrawalQueue.claimableAssetsOf(user1), 0, "user1: claimableAssets");
            vm.roll(block.number + 10); // skip delay
            assertApproxEqAbs(
                withdrawalQueue.claimableAssetsOf(user1), amount1 / 2, 2, "user1: claimableAssets"
            );
        }

        {  // block 2
            vm.prank(user2);
            vault.withdraw(amount2 / 2, user2, user2);
            assertEq(withdrawalQueue.claimableAssetsOf(user2), 0, "user2: claimableAssets");
            vm.roll(block.number + 10); // skip delay
            assertApproxEqAbs(
                withdrawalQueue.claimableAssetsOf(user2), amount2 / 2, 2, "user2: claimableAssets"
            );
        }

        // notice: if block_2 after block_1 -> FAIL with ERC4626ExceededMaxWithdraw, if block_1 after block_2 - OK
        
        return;
    }
}
