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

        address delegationManager = Constants.HOLESKY_EL_DELEGATION_MANAGER;
        IsolatedEigenLayerVaultFactory factory = new IsolatedEigenLayerVaultFactory(
            Constants.HOLESKY_EL_DELEGATION_MANAGER,
            address(new IsolatedEigenLayerVault()),
            address(
                new EigenLayerWithdrawalQueue(
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
                asset: Constants.STETH(),
                name: "MultiVault test",
                symbol: "MVT",
                depositStrategy: address(strategy),
                withdrawalStrategy: address(strategy),
                rebalanceStrategy: address(strategy),
                defaultCollateral: address(0), //Constants.WSTETH_SYMBIOTIC_COLLATERAL(),
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

        vm.expectRevert(
            "RewardsCoordinator._checkClaim: tokenTreeProofs and leaves length mismatch"
        );
        vault.pushRewards(0, abi.encode(rewardsMerkleClaim));

        rewardsMerkleClaim.tokenTreeProofs = new bytes[](1);
        vm.expectRevert(
            "RewardsCoordinator._checkClaim: tokenIndices and tokenProofs length mismatch"
        );
        vault.pushRewards(0, abi.encode(rewardsMerkleClaim));

        rewardsMerkleClaim.tokenIndices = new uint32[](1);
        vm.expectRevert("RewardsCoordinator._verifyEarnerClaimProof: invalid earner claim proof");
        vault.pushRewards(0, abi.encode(rewardsMerkleClaim));

        assertEq(IsolatedEigenLayerVault(isolatedVault).isDelegated(), true, "not delegated");
        address delegation =
            address(IStrategyManager(Constants.HOLESKY_EL_STRATEGY_MANAGER).delegation());
        vm.expectRevert("IsolatedEigenLayerVault: already delegated");
        IsolatedEigenLayerVault(isolatedVault).delegateTo(
            delegation, 0xbF8a8B0d0450c8812ADDf04E1BcB7BfBA0E82937, signature, bytes32(uint256(0))
        );

        vm.expectRevert("Only vault");
        IsolatedEigenLayerVault(isolatedVault).processClaim(
            IRewardsCoordinator(Constants.HOLESKY_EL_REWARDS_COORDINATOR),
            rewardsMerkleClaim,
            IERC20(rewardToken)
        );
    }

    function testMaxDeposit() external {
        address vaultAdmin = rnd.randAddress();
        (MultiVault vault, EigenLayerAdapter eigenLayerAdapter,, address eigenLayerVault) =
            createDefaultMultiVaultWithEigenVault(vaultAdmin, Constants.HOLESKY_EL_STRATEGY);
        IEigenLayerWithdrawalQueue withdrawalQueue =
            EigenLayerWithdrawalQueue(vault.subvaultAt(0).withdrawalQueue);

        uint256 maxDeposit = eigenLayerAdapter.maxDeposit(eigenLayerVault);
        uint256 assets = IERC20(EigenLayerAdapter(eigenLayerAdapter).assetOf(eigenLayerVault))
            .balanceOf(withdrawalQueue.strategy());
        assertEq(maxDeposit, type(uint256).max - assets, "maxDeposit");

        address user = rnd.randAddress();
        uint256 amount = 100 ether;
        deal(user, amount);

        vm.startPrank(user);
        amount = ISTETH(Constants.STETH()).submit{value: amount}(address(0));
        IERC20(Constants.STETH()).approve(address(vault), amount);
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
        assets = IERC20(EigenLayerAdapter(eigenLayerAdapter).assetOf(eigenLayerVault)).balanceOf(
            withdrawalQueue.strategy()
        );
        assertEq(maxDeposit, type(uint256).max - assets, "maxDeposit");

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
            createDefaultMultiVaultWithEigenVault(vaultAdmin, address(0));
        IEigenLayerWithdrawalQueue withdrawalQueue =
            EigenLayerWithdrawalQueue(vault.subvaultAt(0).withdrawalQueue);

        MockStrategyBaseTVLLimits(withdrawalQueue.strategy()).setGetTVLLimitsRevert(true);
        uint256 maxDeposit = eigenLayerAdapter.maxDeposit(eigenLayerVault);
        assertEq(maxDeposit, type(uint256).max, "maxDeposit");
    }

    function testStakedAt() external {
        address vaultAdmin = rnd.randAddress();
        (, EigenLayerAdapter eigenLayerAdapter,, address eigenLayerVault) =
            createDefaultMultiVaultWithEigenVault(vaultAdmin, Constants.HOLESKY_EL_STRATEGY);

        vm.startPrank(0xbF8a8B0d0450c8812ADDf04E1BcB7BfBA0E82937);
        IDelegationManager(Constants.HOLESKY_EL_DELEGATION_MANAGER).undelegate(eigenLayerVault);
        vm.stopPrank();

        vm.expectRevert("EigenLayerAdapter: isolated vault is neither delegated nor shut down");
        eigenLayerAdapter.stakedAt(eigenLayerVault);
    }
}
