// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";
import "../mocks/MockEigenLayerFarm.sol";

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
        address wsteth = Constants.WSTETH();
        address delegationManager = Constants.HOLESKY_EL_DELEGATION_MANAGER;
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

        ISignatureUtilsMixinTypes.SignatureWithExpiry memory signature;
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

        vm.expectRevert(
            "EigenLayerWstETHAdapter: isolated vault is neither delegated nor shut down"
        );
        eigenLayerAdapter.stakedAt(eigenLayerVault);
    }
}
