// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

import "../mocks/MockAVS.sol";
import "../mocks/MockEigenLayerFarm.sol";
import "../solvency/IAllocationManager.sol";

contract Unit is BaseTest {
    using RandomLib for RandomLib.Storage;

    function testEigenLayerWstETHAdapter() external {
        MultiVault vault;
        {
            TransparentUpgradeableProxy c_ = new TransparentUpgradeableProxy(
                address(new MultiVault("test", 1)), vm.createWallet("proxyAdmin").addr, new bytes(0)
            );
            vault = MultiVault(address(c_));
        }
        address isolatedEigenLayerWstETHVault =
            address(new IsolatedEigenLayerWstETHVault(Constants.WSTETH()));
        IsolatedEigenLayerVaultFactory factory = new IsolatedEigenLayerVaultFactory(
            Constants.HOLESKY_EL_DELEGATION_MANAGER,
            isolatedEigenLayerWstETHVault,
            address(
                new EigenLayerWstETHWithdrawalQueue(
                    address(new Claimer()), Constants.HOLESKY_EL_DELEGATION_MANAGER
                )
            ),
            vm.createWallet("proxyAdmin").addr
        );
        IEigenLayerAdapter eigenLayerAdapter = new EigenLayerWstETHAdapter(
            address(factory),
            address(vault),
            IStrategyManager(Constants.HOLESKY_EL_STRATEGY_MANAGER),
            IRewardsCoordinator(Constants.HOLESKY_EL_REWARDS_COORDINATOR),
            Constants.WSTETH()
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

    function testPushRewards() external {
        MultiVault vault;
        {
            TransparentUpgradeableProxy c_ = new TransparentUpgradeableProxy(
                address(new MultiVault("test", 1)), vm.createWallet("proxyAdmin").addr, new bytes(0)
            );
            vault = MultiVault(address(c_));
        }
        address vaultAdmin = rnd.randAddress();
        RatiosStrategy strategy = new RatiosStrategy();
        Claimer claimer = new Claimer();
        IsolatedEigenLayerVaultFactory factory = new IsolatedEigenLayerVaultFactory(
            Constants.HOLESKY_EL_DELEGATION_MANAGER,
            address(new IsolatedEigenLayerWstETHVault(Constants.WSTETH())),
            address(
                new EigenLayerWstETHWithdrawalQueue(
                    address(claimer), Constants.HOLESKY_EL_DELEGATION_MANAGER
                )
            ),
            vm.createWallet("proxyAdmin").addr
        );
        EigenLayerAdapter eigenLayerAdapter = new EigenLayerAdapter(
            address(factory),
            address(vault),
            IStrategyManager(Constants.HOLESKY_EL_STRATEGY_MANAGER),
            IRewardsCoordinator(Constants.HOLESKY_EL_REWARDS_COORDINATOR)
        );

        vault.initialize(
            IMultiVault.InitParams({
                admin: vaultAdmin,
                limit: type(uint256).max,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                asset: Constants.WSTETH(),
                name: "MultiVault test",
                symbol: "MVT",
                depositStrategy: address(strategy),
                withdrawalStrategy: address(strategy),
                rebalanceStrategy: address(strategy),
                defaultCollateral: Constants.WSTETH_SYMBIOTIC_COLLATERAL(),
                symbioticAdapter: address(0),
                eigenLayerAdapter: address(eigenLayerAdapter),
                erc4626Adapter: address(0)
            })
        );

        ISignatureUtils.SignatureWithExpiry memory signature;
        (address isolatedVault,) = factory.getOrCreate(
            address(vault),
            Constants.HOLESKY_EL_STRATEGY,
            0xbF8a8B0d0450c8812ADDf04E1BcB7BfBA0E82937,
            abi.encode(signature, bytes32(0))
        );

        address distributionFarm = rnd.randAddress();
        address curatorTreasury = rnd.randAddress();
        address rewardToken = Constants.WETH();

        vm.startPrank(vaultAdmin);
        vault.grantRole(vault.SET_FARM_ROLE(), vaultAdmin);
        MockEigenLayerFarm mockEigenLayerFarm = new MockEigenLayerFarm();
        vault.setRewardsData(
            0,
            IMultiVaultStorage.RewardData({
                token: rewardToken,
                curatorFeeD6: 1e5,
                distributionFarm: distributionFarm,
                curatorTreasury: curatorTreasury,
                protocol: IMultiVaultStorage.Protocol.EIGEN_LAYER,
                data: abi.encode(address(isolatedVault))
            })
        );

        deal(Constants.WETH(), address(mockEigenLayerFarm), 1 ether);
        vm.stopPrank();

        IERC20 weth = IERC20(Constants.WETH());
        assertEq(weth.balanceOf(distributionFarm), 0, "distribution farm balance should be zero");
        assertEq(weth.balanceOf(curatorTreasury), 0, "curator treasury balance should be zero");

        IRewardsCoordinator.RewardsMerkleClaim memory rewardsMerkleClaim;

        vm.expectRevert("EigenLayerAdapter: invalid farm data");
        vault.pushRewards(0, abi.encode(rewardsMerkleClaim));

        rewardsMerkleClaim.tokenLeaves = new IRewardsCoordinator.TokenTreeMerkleLeaf[](1);
        rewardsMerkleClaim.tokenLeaves[0].token = IERC20(rewardToken);

        vm.expectRevert(abi.encodeWithSignature("InputArrayLengthMismatch()"));
        vault.pushRewards(0, abi.encode(rewardsMerkleClaim));

        rewardsMerkleClaim.tokenTreeProofs = new bytes[](1);
        vm.expectRevert(abi.encodeWithSignature("InputArrayLengthMismatch()"));
        vault.pushRewards(0, abi.encode(rewardsMerkleClaim));

        rewardsMerkleClaim.tokenIndices = new uint32[](1);
        vm.expectRevert(abi.encodeWithSignature("InvalidClaimProof()"));
        vault.pushRewards(0, abi.encode(rewardsMerkleClaim));
    }

    function testMaxDeposit() external {
        address vaultAdmin = rnd.randAddress();
        (MultiVault vault, EigenLayerAdapter eigenLayerAdapter,, address eigenLayerVault) =
            createDefaultMultiVaultWithEigenWstETHVault(vaultAdmin, Constants.HOLESKY_EL_STRATEGY);
        IEigenLayerWithdrawalQueue withdrawalQueue =
            EigenLayerWstETHWithdrawalQueue(vault.subvaultAt(0).withdrawalQueue);

        uint256 maxDeposit = eigenLayerAdapter.maxDeposit(eigenLayerVault);
        assertEq(maxDeposit, type(uint256).max, "maxDeposit");

        address user = rnd.randAddress();
        uint256 amount = 100 ether;
        deal(Constants.WSTETH(), user, amount);

        vm.startPrank(user);
        IERC20(Constants.WSTETH()).approve(address(vault), amount);
        vault.deposit(amount, user);
        vault.withdraw(amount / 2, user, user);
        vm.stopPrank();

        vm.expectRevert("EigenLayerWithdrawalQueue: not yet forcibly unstaked");
        withdrawalQueue.shutdown(uint32(block.number), 0);

        uint256 shares =
            IStrategy(withdrawalQueue.strategy()).shares(withdrawalQueue.isolatedVault());

        IPauserRegistry pauserRegistry = IPauserRegistry(Constants.HOLESKY_EL_PAUSER_REGISTRY);
        vm.startPrank(pauserRegistry.unpauser());
        IPausable(withdrawalQueue.strategy()).pause(uint256(1)); // pause deposit
        vm.stopPrank();

        maxDeposit = eigenLayerAdapter.maxDeposit(eigenLayerVault);
        assertEq(maxDeposit, 0, "maxDeposit not zero");

        vm.startPrank(pauserRegistry.unpauser());
        IPausable(withdrawalQueue.strategy()).unpause(0); // unpause all
        vm.stopPrank();

        maxDeposit = eigenLayerAdapter.maxDeposit(eigenLayerVault);
        assertEq(maxDeposit, type(uint256).max, "maxDeposit");

        vm.startPrank(pauserRegistry.unpauser());
        MockStrategyBaseTVLLimits(withdrawalQueue.strategy()).setTVLLimits(0, 0);
        vm.stopPrank();

        maxDeposit = eigenLayerAdapter.maxDeposit(eigenLayerVault);
        assertEq(maxDeposit, 0, "maxDeposit not zero");

        vm.startPrank(0xbF8a8B0d0450c8812ADDf04E1BcB7BfBA0E82937);
        IDelegationManager(Constants.HOLESKY_EL_DELEGATION_MANAGER).undelegate(eigenLayerVault);
        vm.stopPrank();
        withdrawalQueue.shutdown(uint32(block.number), shares);

        maxDeposit = eigenLayerAdapter.maxDeposit(eigenLayerVault);
        assertEq(maxDeposit, 0, "maxDeposit not zero");
    }

    function testMaxDeposit2() external {
        address vaultAdmin = rnd.randAddress();
        (MultiVault vault, EigenLayerAdapter eigenLayerAdapter,, address eigenLayerVault) =
            createDefaultMultiVaultWithEigenWstETHVault(vaultAdmin, address(0));
        IEigenLayerWithdrawalQueue withdrawalQueue =
            EigenLayerWithdrawalQueue(vault.subvaultAt(0).withdrawalQueue);

        MockStrategyBaseTVLLimits(withdrawalQueue.strategy()).setGetTVLLimitsRevert(true);
        uint256 maxDeposit = eigenLayerAdapter.maxDeposit(eigenLayerVault);
        assertEq(maxDeposit, type(uint256).max, "maxDeposit");
    }

    function testStakedAt() external {
        address vaultAdmin = rnd.randAddress();
        (, EigenLayerAdapter eigenLayerAdapter,, address eigenLayerVault) =
            createDefaultMultiVaultWithEigenWstETHVault(vaultAdmin, Constants.HOLESKY_EL_STRATEGY);

        vm.startPrank(0xbF8a8B0d0450c8812ADDf04E1BcB7BfBA0E82937);
        IDelegationManager(Constants.HOLESKY_EL_DELEGATION_MANAGER).undelegate(eigenLayerVault);
        vm.stopPrank();

        vm.expectRevert("EigenLayerAdapter: isolated vault is neither delegated nor shut down");
        eigenLayerAdapter.stakedAt(eigenLayerVault);
    }

    function testStakedAtAfterSlashingEvent() external {
        address vaultAdmin = rnd.randAddress();
        (MultiVault vault, EigenLayerAdapter eigenLayerAdapter,, address eigenLayerVault) =
            createDefaultMultiVaultWithEigenWstETHVault(vaultAdmin, Constants.HOLESKY_EL_STRATEGY);

        assertEq(eigenLayerAdapter.stakedAt(eigenLayerVault), 0);

        address user = vm.createWallet("user-1").addr;
        {
            vm.startPrank(user);
            address wsteth = Constants.WSTETH();
            deal(wsteth, user, 1 ether);
            IERC20(wsteth).approve(address(vault), 1 ether);
            vault.deposit(1 ether, user);
            vm.stopPrank();
        }

        assertEq(eigenLayerAdapter.stakedAt(eigenLayerVault), 1 ether - 3 wei); // roundings

        (, address elStrategy, address elOperator,) =
            eigenLayerAdapter.factory().instances(eigenLayerVault);
        address allocationManager = 0x78469728304326CBc65f8f95FA756B0B73164462;

        address avs = address(new MockAVS());

        address[] memory strategies = new address[](1);
        strategies[0] = elStrategy;

        vm.startPrank(avs);
        IAllocationManager(allocationManager).updateAVSMetadataURI(avs, "test");

        IAllocationManager.OperatorSet memory operatorSet = IAllocationManager.OperatorSet(avs, 0);
        {
            IAllocationManager.CreateSetParams[] memory x =
                new IAllocationManager.CreateSetParams[](1);
            x[0] = IAllocationManager.CreateSetParams({
                operatorSetId: operatorSet.id,
                strategies: strategies
            });
            IAllocationManager(allocationManager).createOperatorSets(operatorSet.avs, x);
        }

        vm.stopPrank();

        vm.startPrank(elOperator);
        IAllocationManager(allocationManager).setAllocationDelay(elOperator, 1 days);
        vm.roll(block.number + 17.5 days);
        IAllocationManager(allocationManager).registerForOperatorSets(
            elOperator,
            IAllocationManager.RegisterParams({avs: avs, operatorSetIds: new uint32[](1), data: ""})
        );
        vm.stopPrank();

        {
            IAllocationManager.AllocateParams[] memory x =
                new IAllocationManager.AllocateParams[](1);
            x[0] = IAllocationManager.AllocateParams({
                operatorSet: operatorSet,
                strategies: strategies,
                newMagnitudes: new uint64[](1)
            });
            x[0].newMagnitudes[0] = 1 ether;
            vm.startPrank(elOperator);
            IAllocationManager(allocationManager).modifyAllocations(elOperator, x);
            vm.roll(block.number + 20 days);
            vm.stopPrank();
        }

        uint256[] memory wadsToSlash = new uint256[](1);
        wadsToSlash[0] = 0.5 ether;

        vm.startPrank(address(avs));
        IAllocationManager(allocationManager).slashOperator(
            avs,
            IAllocationManager.SlashingParams({
                operator: elOperator,
                operatorSetId: 0,
                strategies: strategies,
                wadsToSlash: wadsToSlash,
                description: "test"
            })
        );

        assertEq(eigenLayerAdapter.stakedAt(eigenLayerVault), 0.5 ether - 3 wei, "~50% slashing");
        assertEq(vault.totalAssets(), 0.5 ether - 3 wei, "~50% slashing (totalAssets)");
        vm.stopPrank();

        vm.startPrank(user);
        assertEq(vault.totalAssets(), 0.5 ether - 3 wei, "~50% slashing (totalAssets) 2");
        vault.redeem(vault.balanceOf(user), user, user);
        assertEq(vault.totalAssets(), 2, "~50% slashing (totalAssets) 3");

        vm.roll(block.number + 1e3);

        uint256 delta = IERC20(Constants.WSTETH()).balanceOf(user);
        EigenLayerWithdrawalQueue(vault.subvaultAt(0).withdrawalQueue).claim(
            user, user, type(uint256).max
        );
        delta = IERC20(Constants.WSTETH()).balanceOf(user) - delta;
        // wtf??
        assertEq(delta, 0.5 ether - 6);

        assertEq(vault.totalSupply(), 0, "Invalid total supply");
        assertEq(vault.totalAssets(), 2, "Invalid total assets");

        vm.stopPrank();
    }
}
