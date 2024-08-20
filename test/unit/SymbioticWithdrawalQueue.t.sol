// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../Imports.sol";

contract Integration is Test {
    /*
        forge test -vvvv  --match-path ./test/DWFlowTest.t.sol --fork-url $(grep HOLESKY_RPC .env | cut -d '=' -f2,3,4,5)  --fork-block-number 2160000
    */

    address admin = makeAddr("admin");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address limitIncreaser = makeAddr("limitIncreaser");

    uint64 vaultVersion = 1;
    address vaultOwner = makeAddr("vaultOwner");
    address vaultAdmin = makeAddr("vaultAdmin");
    uint48 epochDuration = 3600;
    address wsteth = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;
    address steth = 0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034;
    address weth = 0x94373a4919B3240D86eA41593D5eBa789FEF3848;

    function testWithdrawalQueue() external {
        require(block.chainid == 17000, "This test can only be run on the Holesky testnet");

        MellowSymbioticVotesVault singleton =
            new MellowSymbioticVotesVault("MellowSymbioticVotesVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        ISymbioticVault symbioticVault = ISymbioticVault(
            SymbioticHelperLibrary.createNewSymbioticVault(
                SymbioticHelperLibrary.CreationParams({
                    limitIncreaser: limitIncreaser,
                    vaultOwner: vaultOwner,
                    vaultAdmin: vaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    limit: 1000 ether
                })
            )
        );

        (IMellowSymbioticVault mellowSymbioticVault, IWithdrawalQueue withdrawalQueue) = factory
            .create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: makeAddr("proxyAdmin"),
                limit: 1000 ether,
                symbioticVault: address(symbioticVault),
                admin: admin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        uint256 amount1 = 100 ether;
        uint256 amount2 = 10 ether;

        deal(wsteth, user1, amount1);
        deal(wsteth, user2, amount2);

        uint256 nextEpochStartIn = epochDuration - (block.timestamp % epochDuration);
        skip(nextEpochStartIn);

        vm.startPrank(user1);
        IERC20(wsteth).approve(address(mellowSymbioticVault), amount1);
        mellowSymbioticVault.deposit(amount1, user1);
        mellowSymbioticVault.withdraw(amount1 / 2, user1, user1);
        vm.stopPrank();

        // new epoch
        skip(epochDuration);

        vm.startPrank(user2);
        IERC20(wsteth).approve(address(mellowSymbioticVault), amount2);
        mellowSymbioticVault.deposit(amount2, user2);
        mellowSymbioticVault.withdraw(amount2 / 2, user2, user2);
        vm.stopPrank();

        assertEq(
            withdrawalQueue.pendingAssetsOf(user1), amount1 / 2, "initial pendingAssetsOf(user1)"
        );
        assertEq(withdrawalQueue.claimableAssetsOf(user1), 0, "initial claimableAssetsOf(user1)");

        assertEq(
            withdrawalQueue.pendingAssetsOf(user2), amount2 / 2, "initial pendingAssetsOf(user2)"
        );
        assertEq(withdrawalQueue.claimableAssetsOf(user2), 0, "initial claimableAssetsOf(user2)");

        // new epoch
        skip(epochDuration);

        assertEq(withdrawalQueue.pendingAssetsOf(user1), 0, "stage 1: pendingAssetsOf(user1)");
        assertEq(
            withdrawalQueue.claimableAssetsOf(user1),
            amount1 / 2,
            "stage 1: claimableAssetsOf(user1)"
        );

        assertEq(
            withdrawalQueue.pendingAssetsOf(user2), amount2 / 2, "stage 1: pendingAssetsOf(user2)"
        );
        assertEq(withdrawalQueue.claimableAssetsOf(user2), 0, "stage 1: claimableAssetsOf(user2)");

        skip(epochDuration);

        assertEq(withdrawalQueue.pendingAssetsOf(user1), 0, "stage 2: pendingAssetsOf(user1)");
        assertEq(
            withdrawalQueue.claimableAssetsOf(user1),
            amount1 / 2,
            "stage 2: claimableAssetsOf(user1)"
        );

        assertEq(withdrawalQueue.pendingAssetsOf(user2), 0, "stage 2: pendingAssetsOf(user2)");
        assertEq(
            withdrawalQueue.claimableAssetsOf(user2),
            amount2 / 2,
            "stage 2: claimableAssetsOf(user2)"
        );
    }

    function testWithdrawalQueueMultipleRequests() external {
        require(block.chainid == 17000, "This test can only be run on the Holesky testnet");

        MellowSymbioticVotesVault singleton =
            new MellowSymbioticVotesVault("MellowSymbioticVotesVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        ISymbioticVault symbioticVault = ISymbioticVault(
            SymbioticHelperLibrary.createNewSymbioticVault(
                SymbioticHelperLibrary.CreationParams({
                    limitIncreaser: limitIncreaser,
                    vaultOwner: vaultOwner,
                    vaultAdmin: vaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    limit: 1000 ether
                })
            )
        );

        (IMellowSymbioticVault mellowSymbioticVault, IWithdrawalQueue withdrawalQueue) = factory
            .create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: makeAddr("proxyAdmin"),
                limit: 1000 ether,
                symbioticVault: address(symbioticVault),
                admin: admin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        uint256 amount1 = 100 ether;

        deal(wsteth, user1, amount1);

        uint256 nextEpochStartIn = epochDuration - (block.timestamp % epochDuration);
        skip(nextEpochStartIn);

        vm.startPrank(user1);
        IERC20(wsteth).approve(address(mellowSymbioticVault), amount1);
        mellowSymbioticVault.deposit(amount1, user1);
        mellowSymbioticVault.withdraw(amount1 / 10, user1, user1);
        vm.stopPrank();

        assertEq(
            withdrawalQueue.pendingAssetsOf(user1), amount1 / 10, "initial pendingAssetsOf(user1)"
        );
        assertEq(withdrawalQueue.claimableAssetsOf(user1), 0, "initial claimableAssetsOf(user1)");

        // new epoch
        skip(epochDuration);

        assertEq(
            withdrawalQueue.pendingAssetsOf(user1), amount1 / 10, "stage 1: pendingAssetsOf(user1)"
        );
        assertEq(withdrawalQueue.claimableAssetsOf(user1), 0, "stage 1: claimableAssetsOf(user1)");

        vm.prank(user1);
        mellowSymbioticVault.withdraw(amount1 / 10, user1, user1);

        assertEq(
            withdrawalQueue.pendingAssetsOf(user1),
            2 * amount1 / 10,
            "stage 2: pendingAssetsOf(user1)"
        );
        assertEq(withdrawalQueue.claimableAssetsOf(user1), 0, "stage 2: claimableAssetsOf(user1)");

        skip(epochDuration);

        assertEq(
            withdrawalQueue.pendingAssetsOf(user1), amount1 / 10, "stage 3: pendingAssetsOf(user1)"
        );
        assertEq(
            withdrawalQueue.claimableAssetsOf(user1),
            amount1 / 10,
            "stage 3: claimableAssetsOf(user1)"
        );

        skip(epochDuration);

        assertEq(withdrawalQueue.pendingAssetsOf(user1), 0, "stage 4: pendingAssetsOf(user1)");
        assertEq(
            withdrawalQueue.claimableAssetsOf(user1),
            2 * amount1 / 10,
            "stage 4: claimableAssetsOf(user1)"
        );

        vm.prank(user1);
        withdrawalQueue.claim(user1, user1, type(uint256).max);

        assertEq(withdrawalQueue.pendingAssetsOf(user1), 0, "stage 5: pendingAssetsOf(user1)");
        assertEq(withdrawalQueue.claimableAssetsOf(user1), 0, "stage 5: claimableAssetsOf(user1)");
    }

    function testCurrentEpoch() external {
        require(block.chainid == 17000, "This test can only be run on the Holesky testnet");

        MellowSymbioticVotesVault singleton =
            new MellowSymbioticVotesVault("MellowSymbioticVotesVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        ISymbioticVault symbioticVault = ISymbioticVault(
            SymbioticHelperLibrary.createNewSymbioticVault(
                SymbioticHelperLibrary.CreationParams({
                    limitIncreaser: limitIncreaser,
                    vaultOwner: vaultOwner,
                    vaultAdmin: vaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    limit: 1000 ether
                })
            )
        );

        ( /*IMellowSymbioticVault mellowSymbioticVault*/ , IWithdrawalQueue wq) = factory.create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: makeAddr("proxyAdmin"),
                limit: 1000 ether,
                symbioticVault: address(symbioticVault),
                admin: admin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        SymbioticWithdrawalQueue withdrawalQueue = SymbioticWithdrawalQueue(address(wq));

        assertEq(withdrawalQueue.currentEpoch(), 0, "initial currentEpoch");
        assertEq(symbioticVault.currentEpoch(), 0, "initial currentEpoch");
        skip(epochDuration);

        assertEq(withdrawalQueue.currentEpoch(), 1, "stage 1: currentEpoch");
        assertEq(symbioticVault.currentEpoch(), 1, "stage 1: currentEpoch");
        skip(epochDuration);

        assertEq(withdrawalQueue.currentEpoch(), 2, "stage 2: currentEpoch");
        assertEq(symbioticVault.currentEpoch(), 2, "stage 2: currentEpoch");
        skip(epochDuration);

        assertEq(withdrawalQueue.currentEpoch(), 3, "stage 3: currentEpoch");
        assertEq(symbioticVault.currentEpoch(), 3, "stage 3: currentEpoch");
    }

    function testPendingAssets() external {
        require(block.chainid == 17000, "This test can only be run on the Holesky testnet");

        MellowSymbioticVotesVault singleton =
            new MellowSymbioticVotesVault("MellowSymbioticVotesVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        ISymbioticVault symbioticVault = ISymbioticVault(
            SymbioticHelperLibrary.createNewSymbioticVault(
                SymbioticHelperLibrary.CreationParams({
                    limitIncreaser: limitIncreaser,
                    vaultOwner: vaultOwner,
                    vaultAdmin: vaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    limit: 1000 ether
                })
            )
        );

        (IMellowSymbioticVault mellowSymbioticVault, IWithdrawalQueue withdrawalQueue) = factory
            .create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: makeAddr("proxyAdmin"),
                limit: 1000 ether,
                symbioticVault: address(symbioticVault),
                admin: admin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        uint256 amount1 = 100 ether;
        uint256 amount2 = 10 ether;

        deal(wsteth, user1, amount1);
        deal(wsteth, user2, amount2);

        vm.startPrank(user1);
        IERC20(wsteth).approve(address(mellowSymbioticVault), amount1);
        mellowSymbioticVault.deposit(amount1, user1);
        mellowSymbioticVault.withdraw(amount1 / 2, user1, user1);
        vm.stopPrank();

        // new epoch
        skip(epochDuration);

        vm.startPrank(user2);
        IERC20(wsteth).approve(address(mellowSymbioticVault), amount2);
        mellowSymbioticVault.deposit(amount2, user2);
        mellowSymbioticVault.withdraw(amount2 / 2, user2, user2);
        vm.stopPrank();

        assertEq(
            withdrawalQueue.pendingAssets(), amount1 / 2 + amount2 / 2, "epoch 0: pendingAssets"
        );
        skip(epochDuration);
        assertEq(withdrawalQueue.pendingAssets(), amount2 / 2, "epoch 1: pendingAssets");
        skip(epochDuration);
        assertEq(withdrawalQueue.pendingAssets(), 0, "epoch 2: pendingAssets");
    }

    function testBalanceOf() external {
        require(block.chainid == 17000, "This test can only be run on the Holesky testnet");

        MellowSymbioticVotesVault singleton =
            new MellowSymbioticVotesVault("MellowSymbioticVotesVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        ISymbioticVault symbioticVault = ISymbioticVault(
            SymbioticHelperLibrary.createNewSymbioticVault(
                SymbioticHelperLibrary.CreationParams({
                    limitIncreaser: limitIncreaser,
                    vaultOwner: vaultOwner,
                    vaultAdmin: vaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    limit: 1000 ether
                })
            )
        );

        (IMellowSymbioticVault mellowSymbioticVault, IWithdrawalQueue withdrawalQueue) = factory
            .create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: makeAddr("proxyAdmin"),
                limit: 1000 ether,
                symbioticVault: address(symbioticVault),
                admin: admin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        uint256 amount1 = 100 ether;
        uint256 amount2 = 10 ether;

        deal(wsteth, user1, amount1);
        deal(wsteth, user2, amount2);

        vm.startPrank(user1);
        IERC20(wsteth).approve(address(mellowSymbioticVault), amount1);
        mellowSymbioticVault.deposit(amount1, user1);
        mellowSymbioticVault.withdraw(amount1 / 2, user1, user1);
        vm.stopPrank();

        // new epoch
        skip(epochDuration);

        vm.startPrank(user2);
        IERC20(wsteth).approve(address(mellowSymbioticVault), amount2);
        mellowSymbioticVault.deposit(amount2, user2);
        mellowSymbioticVault.withdraw(amount2 / 2, user2, user2);
        vm.stopPrank();

        assertEq(withdrawalQueue.balanceOf(user1), amount1 / 2, "user1 balance");
        assertEq(withdrawalQueue.balanceOf(user2), amount2 / 2, "user2 balance");

        skip(epochDuration);

        assertEq(withdrawalQueue.balanceOf(user1), amount1 / 2, "user1 balance");
        assertEq(withdrawalQueue.balanceOf(user2), amount2 / 2, "user2 balance");

        skip(epochDuration);

        assertEq(withdrawalQueue.balanceOf(user1), amount1 / 2, "user1 balance");
        assertEq(withdrawalQueue.balanceOf(user2), amount2 / 2, "user2 balance");

        skip(epochDuration);

        vm.prank(user1);
        withdrawalQueue.claim(user1, user1, amount1 / 2 - 1);

        assertEq(withdrawalQueue.balanceOf(user1), 1, "user1 balance");
        assertEq(withdrawalQueue.balanceOf(user2), amount2 / 2, "user2 balance");
    }

    function testPendingAssetsOf() external {
        require(block.chainid == 17000, "This test can only be run on the Holesky testnet");

        MellowSymbioticVotesVault singleton =
            new MellowSymbioticVotesVault("MellowSymbioticVotesVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        ISymbioticVault symbioticVault = ISymbioticVault(
            SymbioticHelperLibrary.createNewSymbioticVault(
                SymbioticHelperLibrary.CreationParams({
                    limitIncreaser: limitIncreaser,
                    vaultOwner: vaultOwner,
                    vaultAdmin: vaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    limit: 1000 ether
                })
            )
        );

        (IMellowSymbioticVault mellowSymbioticVault, IWithdrawalQueue withdrawalQueue) = factory
            .create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: makeAddr("proxyAdmin"),
                limit: 1000 ether,
                symbioticVault: address(symbioticVault),
                admin: admin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        uint256 amount1 = 100 ether;
        uint256 amount2 = 10 ether;

        deal(wsteth, user1, amount1);
        deal(wsteth, user2, amount2);

        vm.startPrank(user1);
        IERC20(wsteth).approve(address(mellowSymbioticVault), amount1);
        mellowSymbioticVault.deposit(amount1, user1);
        mellowSymbioticVault.withdraw(amount1 / 2, user1, user1);
        vm.stopPrank();

        // new epoch
        skip(epochDuration);

        vm.startPrank(user2);
        IERC20(wsteth).approve(address(mellowSymbioticVault), amount2);
        mellowSymbioticVault.deposit(amount2, user2);
        mellowSymbioticVault.withdraw(amount2 / 2, user2, user2);
        vm.stopPrank();

        assertEq(withdrawalQueue.pendingAssetsOf(user1), amount1 / 2, "user1: pendingAssets");

        assertEq(withdrawalQueue.pendingAssetsOf(user2), amount2 / 2, "user2: pendingAssets");

        skip(epochDuration);

        assertEq(withdrawalQueue.pendingAssetsOf(user1), 0, "user1: pendingAssets");
        assertEq(withdrawalQueue.pendingAssetsOf(user2), amount2 / 2, "user2: pendingAssets");

        skip(epochDuration);

        assertEq(withdrawalQueue.pendingAssetsOf(user1), 0, "user1: pendingAssets");
        assertEq(withdrawalQueue.pendingAssetsOf(user2), 0, "user2: pendingAssets");

        vm.prank(user1);
        withdrawalQueue.claim(user1, user1, amount1 / 2 - 1);

        assertEq(withdrawalQueue.pendingAssetsOf(user1), 0, "user1: pendingAssets");
        assertEq(withdrawalQueue.pendingAssetsOf(user2), 0, "user2: pendingAssets");

        vm.prank(user1);
        withdrawalQueue.claim(user1, user1, 1);

        assertEq(withdrawalQueue.pendingAssetsOf(user1), 0, "user1: pendingAssets");
        assertEq(withdrawalQueue.pendingAssetsOf(user2), 0, "user2: pendingAssets");
    }

    function testClaimableAssetsOf() external {
        require(block.chainid == 17000, "This test can only be run on the Holesky testnet");

        MellowSymbioticVotesVault singleton =
            new MellowSymbioticVotesVault("MellowSymbioticVotesVault", 1);
        MellowSymbioticVaultFactory factory = new MellowSymbioticVaultFactory(address(singleton));

        ISymbioticVault symbioticVault = ISymbioticVault(
            SymbioticHelperLibrary.createNewSymbioticVault(
                SymbioticHelperLibrary.CreationParams({
                    limitIncreaser: limitIncreaser,
                    vaultOwner: vaultOwner,
                    vaultAdmin: vaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    limit: 1000 ether
                })
            )
        );

        (IMellowSymbioticVault mellowSymbioticVault, IWithdrawalQueue withdrawalQueue) = factory
            .create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: makeAddr("proxyAdmin"),
                limit: 1000 ether,
                symbioticVault: address(symbioticVault),
                admin: admin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );

        uint256 amount1 = 100 ether;
        uint256 amount2 = 10 ether;

        deal(wsteth, user1, amount1);
        deal(wsteth, user2, amount2);

        vm.startPrank(user1);
        IERC20(wsteth).approve(address(mellowSymbioticVault), amount1);
        mellowSymbioticVault.deposit(amount1, user1);
        mellowSymbioticVault.withdraw(amount1 / 2, user1, user1);
        vm.stopPrank();

        // new epoch
        skip(epochDuration);

        vm.startPrank(user2);
        IERC20(wsteth).approve(address(mellowSymbioticVault), amount2);
        mellowSymbioticVault.deposit(amount2, user2);
        mellowSymbioticVault.withdraw(amount2 / 2, user2, user2);
        vm.stopPrank();

        assertEq(withdrawalQueue.claimableAssetsOf(user1), 0, "user1: claimableAssets");
        assertEq(withdrawalQueue.claimableAssetsOf(user2), 0, "user2: claimableAssets");

        skip(epochDuration);

        assertEq(withdrawalQueue.claimableAssetsOf(user1), amount1 / 2, "user1: claimableAssets");
        assertEq(withdrawalQueue.claimableAssetsOf(user2), 0, "user2: claimableAssets");

        skip(epochDuration);

        assertEq(withdrawalQueue.claimableAssetsOf(user1), amount1 / 2, "user1: claimableAssets");
        assertEq(withdrawalQueue.claimableAssetsOf(user2), amount2 / 2, "user2: claimableAssets");

        vm.prank(user1);
        withdrawalQueue.claim(user1, user1, amount1 / 2 - 1);

        assertEq(withdrawalQueue.claimableAssetsOf(user1), 1, "user1: claimableAssets");
        assertEq(withdrawalQueue.claimableAssetsOf(user2), amount2 / 2, "user2: claimableAssets");

        vm.prank(user1);
        withdrawalQueue.claim(user1, user1, 1);

        assertEq(withdrawalQueue.claimableAssetsOf(user1), 0, "user1: claimableAssets");
        assertEq(withdrawalQueue.claimableAssetsOf(user2), amount2 / 2, "user2: claimableAssets");
    }
}
