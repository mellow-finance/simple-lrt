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

contract MockAVS {
    function supportsAVS(address) external pure returns (bool) {
        return true;
    }

    fallback() external {}
}

interface IAllocationManager {
    struct OperatorSet {
        address avs;
        uint32 id;
    }

    struct Allocation {
        uint64 currentMagnitude;
        int128 pendingDiff;
        uint32 effectBlock;
    }

    /**
     * @notice Struct containing allocation delay metadata for a given operator.
     * @param delay Current allocation delay
     * @param isSet Whether the operator has initially set an allocation delay. Note that this could be false but the
     * block.number >= effectBlock in which we consider their delay to be configured and active.
     * @param pendingDelay The delay that will take effect after `effectBlock`
     * @param effectBlock The block number after which a pending delay will take effect
     */
    struct AllocationDelayInfo {
        uint32 delay;
        bool isSet;
        uint32 pendingDelay;
        uint32 effectBlock;
    }

    /**
     * @notice Contains registration details for an operator pertaining to an operator set
     * @param registered Whether the operator is currently registered for the operator set
     * @param slashableUntil If the operator is not registered, they are still slashable until
     * this block is reached.
     */
    struct RegistrationStatus {
        bool registered;
        uint32 slashableUntil;
    }

    struct StrategyInfo {
        uint64 maxMagnitude;
        uint64 encumberedMagnitude;
    }

    struct SlashingParams {
        address operator;
        uint32 operatorSetId;
        address[] strategies;
        uint256[] wadsToSlash;
        string description;
    }

    struct AllocateParams {
        OperatorSet operatorSet;
        address[] strategies;
        uint64[] newMagnitudes;
    }

    /**
     * @notice Parameters used to register for an AVS's operator sets
     * @param avs the AVS being registered for
     * @param operatorSetIds the operator sets within the AVS to register for
     * @param data extra data to be passed to the AVS to complete registration
     */
    struct RegisterParams {
        address avs;
        uint32[] operatorSetIds;
        bytes data;
    }

    /**
     * @notice Parameters used to deregister from an AVS's operator sets
     * @param operator the operator being deregistered
     * @param avs the avs being deregistered from
     * @param operatorSetIds the operator sets within the AVS being deregistered from
     */
    struct DeregisterParams {
        address operator;
        address avs;
        uint32[] operatorSetIds;
    }

    /**
     * @notice Parameters used by an AVS to create new operator sets
     * @param operatorSetId the id of the operator set to create
     * @param strategies the strategies to add as slashable to the operator set
     */
    struct CreateSetParams {
        uint32 operatorSetId;
        address[] strategies;
    }

    /**
     * @dev Initializes the initial owner and paused status.
     */
    function initialize(address initialOwner, uint256 initialPausedStatus) external;

    /**
     * @notice Called by an AVS to slash an operator in a given operator set. The operator must be registered
     * and have slashable stake allocated to the operator set.
     *
     * @param avs The AVS address initiating the slash.
     * @param params The slashing parameters, containing:
     *  - operator: The operator to slash.
     *  - operatorSetId: The ID of the operator set the operator is being slashed from.
     *  - strategies: Array of strategies to slash allocations from (must be in ascending order).
     *  - wadsToSlash: Array of proportions to slash from each strategy (must be between 0 and 1e18).
     *  - description: Description of why the operator was slashed.
     *
     * @dev For each strategy:
     *      1. Reduces the operator's current allocation magnitude by wadToSlash proportion.
     *      2. Reduces the strategy's max and encumbered magnitudes proportionally.
     *      3. If there is a pending deallocation, reduces it proportionally.
     *      4. Updates the operator's shares in the DelegationManager.
     *
     * @dev Small slashing amounts may not result in actual token burns due to
     *      rounding, which will result in small amounts of tokens locked in the contract
     *      rather than fully burning through the burn mechanism.
     */
    function slashOperator(address avs, SlashingParams calldata params) external;

    /**
     * @notice Modifies the proportions of slashable stake allocated to an operator set from a list of strategies
     * Note that deallocations remain slashable for DEALLOCATION_DELAY blocks therefore when they are cleared they may
     * free up less allocatable magnitude than initially deallocated.
     * @param operator the operator to modify allocations for
     * @param params array of magnitude adjustments for one or more operator sets
     * @dev Updates encumberedMagnitude for the updated strategies
     */
    function modifyAllocations(address operator, AllocateParams[] calldata params) external;

    /**
     * @notice This function takes a list of strategies and for each strategy, removes from the deallocationQueue
     * all clearable deallocations up to max `numToClear` number of deallocations, updating the encumberedMagnitude
     * of the operator as needed.
     *
     * @param operator address to clear deallocations for
     * @param strategies a list of strategies to clear deallocations for
     * @param numToClear a list of number of pending deallocations to clear for each strategy
     *
     * @dev can be called permissionlessly by anyone
     */
    function clearDeallocationQueue(
        address operator,
        IStrategy[] calldata strategies,
        uint16[] calldata numToClear
    ) external;

    /**
     * @notice Allows an operator to register for one or more operator sets for an AVS. If the operator
     * has any stake allocated to these operator sets, it immediately becomes slashable.
     * @dev After registering within the ALM, this method calls the AVS Registrar's `IAVSRegistrar.
     * registerOperator` method to complete registration. This call MUST succeed in order for
     * registration to be successful.
     */
    function registerForOperatorSets(address operator, RegisterParams calldata params) external;

    /**
     * @notice Allows an operator or AVS to deregister the operator from one or more of the AVS's operator sets.
     * If the operator has any slashable stake allocated to the AVS, it remains slashable until the
     * DEALLOCATION_DELAY has passed.
     * @dev After deregistering within the ALM, this method calls the AVS Registrar's `IAVSRegistrar.
     * deregisterOperator` method to complete deregistration. This call MUST succeed in order for
     * deregistration to be successful.
     */
    function deregisterFromOperatorSets(DeregisterParams calldata params) external;

    /**
     * @notice Called by the delegation manager OR an operator to set an operator's allocation delay.
     * This is set when the operator first registers, and is the number of blocks between an operator
     * allocating magnitude to an operator set, and the magnitude becoming slashable.
     * @param operator The operator to set the delay on behalf of.
     * @param delay the allocation delay in blocks
     */
    function setAllocationDelay(address operator, uint32 delay) external;

    /**
     * @notice Called by an AVS to configure the address that is called when an operator registers
     * or is deregistered from the AVS's operator sets. If not set (or set to 0), defaults
     * to the AVS's address.
     * @param registrar the new registrar address
     */
    function setAVSRegistrar(address avs, address registrar) external;

    /**
     *  @notice Called by an AVS to emit an `AVSMetadataURIUpdated` event indicating the information has updated.
     *
     *  @param metadataURI The URI for metadata associated with an AVS.
     *
     *  @dev Note that the `metadataURI` is *never stored* and is only emitted in the `AVSMetadataURIUpdated` event.
     */
    function updateAVSMetadataURI(address avs, string calldata metadataURI) external;

    /**
     * @notice Allows an AVS to create new operator sets, defining strategies that the operator set uses
     */
    function createOperatorSets(address avs, CreateSetParams[] calldata params) external;

    /**
     * @notice Allows an AVS to add strategies to an operator set
     * @dev Strategies MUST NOT already exist in the operator set
     * @param avs the avs to set strategies for
     * @param operatorSetId the operator set to add strategies to
     * @param strategies the strategies to add
     */
    function addStrategiesToOperatorSet(
        address avs,
        uint32 operatorSetId,
        IStrategy[] calldata strategies
    ) external;

    /**
     * @notice Allows an AVS to remove strategies from an operator set
     * @dev Strategies MUST already exist in the operator set
     * @param avs the avs to remove strategies for
     * @param operatorSetId the operator set to remove strategies from
     * @param strategies the strategies to remove
     */
    function removeStrategiesFromOperatorSet(
        address avs,
        uint32 operatorSetId,
        IStrategy[] calldata strategies
    ) external;

    /**
     *
     *                         VIEW FUNCTIONS
     *
     */

    /**
     * @notice Returns the number of operator sets for the AVS
     * @param avs the AVS to query
     */
    function getOperatorSetCount(address avs) external view returns (uint256);

    /**
     * @notice Returns the list of operator sets the operator has current or pending allocations/deallocations in
     * @param operator the operator to query
     * @return the list of operator sets the operator has current or pending allocations/deallocations in
     */
    function getAllocatedSets(address operator) external view returns (OperatorSet[] memory);

    /**
     * @notice Returns the list of strategies an operator has current or pending allocations/deallocations from
     * given a specific operator set.
     * @param operator the operator to query
     * @param operatorSet the operator set to query
     * @return the list of strategies
     */
    function getAllocatedStrategies(address operator, OperatorSet memory operatorSet)
        external
        view
        returns (IStrategy[] memory);

    /**
     * @notice Returns the current/pending stake allocation an operator has from a strategy to an operator set
     * @param operator the operator to query
     * @param operatorSet the operator set to query
     * @param strategy the strategy to query
     * @return the current/pending stake allocation
     */
    function getAllocation(address operator, OperatorSet memory operatorSet, IStrategy strategy)
        external
        view
        returns (Allocation memory);

    /**
     * @notice Returns the current/pending stake allocations for multiple operators from a strategy to an operator set
     * @param operators the operators to query
     * @param operatorSet the operator set to query
     * @param strategy the strategy to query
     * @return each operator's allocation
     */
    function getAllocations(
        address[] memory operators,
        OperatorSet memory operatorSet,
        IStrategy strategy
    ) external view returns (Allocation[] memory);

    /**
     * @notice Given a strategy, returns a list of operator sets and corresponding stake allocations.
     * @dev Note that this returns a list of ALL operator sets the operator has allocations in. This means
     * some of the returned allocations may be zero.
     * @param operator the operator to query
     * @param strategy the strategy to query
     * @return the list of all operator sets the operator has allocations for
     * @return the corresponding list of allocations from the specific `strategy`
     */
    function getStrategyAllocations(address operator, IStrategy strategy)
        external
        view
        returns (OperatorSet[] memory, Allocation[] memory);

    /**
     * @notice For a strategy, get the amount of magnitude that is allocated across one or more operator sets
     * @param operator the operator to query
     * @param strategy the strategy to get allocatable magnitude for
     * @return currently allocated magnitude
     */
    function getEncumberedMagnitude(address operator, IStrategy strategy)
        external
        view
        returns (uint64);

    /**
     * @notice For a strategy, get the amount of magnitude not currently allocated to any operator set
     * @param operator the operator to query
     * @param strategy the strategy to get allocatable magnitude for
     * @return magnitude available to be allocated to an operator set
     */
    function getAllocatableMagnitude(address operator, IStrategy strategy)
        external
        view
        returns (uint64);

    /**
     * @notice Returns the maximum magnitude an operator can allocate for the given strategy
     * @dev The max magnitude of an operator starts at WAD (1e18), and is decreased anytime
     * the operator is slashed. This value acts as a cap on the max magnitude of the operator.
     * @param operator the operator to query
     * @param strategy the strategy to get the max magnitude for
     * @return the max magnitude for the strategy
     */
    function getMaxMagnitude(address operator, IStrategy strategy) external view returns (uint64);

    /**
     * @notice Returns the maximum magnitude an operator can allocate for the given strategies
     * @dev The max magnitude of an operator starts at WAD (1e18), and is decreased anytime
     * the operator is slashed. This value acts as a cap on the max magnitude of the operator.
     * @param operator the operator to query
     * @param strategies the strategies to get the max magnitudes for
     * @return the max magnitudes for each strategy
     */
    function getMaxMagnitudes(address operator, IStrategy[] calldata strategies)
        external
        view
        returns (uint64[] memory);

    /**
     * @notice Returns the maximum magnitudes each operator can allocate for the given strategy
     * @dev The max magnitude of an operator starts at WAD (1e18), and is decreased anytime
     * the operator is slashed. This value acts as a cap on the max magnitude of the operator.
     * @param operators the operators to query
     * @param strategy the strategy to get the max magnitudes for
     * @return the max magnitudes for each operator
     */
    function getMaxMagnitudes(address[] calldata operators, IStrategy strategy)
        external
        view
        returns (uint64[] memory);

    /**
     * @notice Returns the maximum magnitude an operator can allocate for the given strategies
     * at a given block number
     * @dev The max magnitude of an operator starts at WAD (1e18), and is decreased anytime
     * the operator is slashed. This value acts as a cap on the max magnitude of the operator.
     * @param operator the operator to query
     * @param strategies the strategies to get the max magnitudes for
     * @param blockNumber the blockNumber at which to check the max magnitudes
     * @return the max magnitudes for each strategy
     */
    function getMaxMagnitudesAtBlock(
        address operator,
        IStrategy[] calldata strategies,
        uint32 blockNumber
    ) external view returns (uint64[] memory);

    /**
     * @notice Returns the time in blocks between an operator allocating slashable magnitude
     * and the magnitude becoming slashable. If the delay has not been set, `isSet` will be false.
     * @dev The operator must have a configured delay before allocating magnitude
     * @param operator The operator to query
     * @return isSet Whether the operator has configured a delay
     * @return delay The time in blocks between allocating magnitude and magnitude becoming slashable
     */
    function getAllocationDelay(address operator)
        external
        view
        returns (bool isSet, uint32 delay);

    /**
     * @notice Returns a list of all operator sets the operator is registered for
     * @param operator The operator address to query.
     */
    function getRegisteredSets(address operator)
        external
        view
        returns (OperatorSet[] memory operatorSets);

    /**
     * @notice Returns whether the operator is registered for the operator set
     * @param operator The operator to query
     * @param operatorSet The operator set to query
     */
    function isMemberOfOperatorSet(address operator, OperatorSet memory operatorSet)
        external
        view
        returns (bool);

    /**
     * @notice Returns whether the operator set exists
     */
    function isOperatorSet(OperatorSet memory operatorSet) external view returns (bool);

    /**
     * @notice Returns all the operators registered to an operator set
     * @param operatorSet The operatorSet to query.
     */
    function getMembers(OperatorSet memory operatorSet)
        external
        view
        returns (address[] memory operators);

    /**
     * @notice Returns the number of operators registered to an operatorSet.
     * @param operatorSet The operatorSet to get the member count for
     */
    function getMemberCount(OperatorSet memory operatorSet) external view returns (uint256);

    /**
     * @notice Returns the address that handles registration/deregistration for the AVS
     * If not set, defaults to the input address (`avs`)
     */
    function getAVSRegistrar(address avs) external view returns (address);

    /**
     * @notice Returns an array of strategies in the operatorSet.
     * @param operatorSet The operatorSet to query.
     */
    function getStrategiesInOperatorSet(OperatorSet memory operatorSet)
        external
        view
        returns (IStrategy[] memory strategies);

    /**
     * @notice Returns the minimum amount of stake that will be slashable as of some future block,
     * according to each operator's allocation from each strategy to the operator set. Note that this function
     * will return 0 for the slashable stake if the operator is not slashable at the time of the call.
     * @dev This method queries actual delegated stakes in the DelegationManager and applies
     * each operator's allocation to the stake to produce the slashable stake each allocation
     * represents. This method does not consider slashable stake in the withdrawal queue even though there could be
     * slashable stake in the queue.
     * @dev This minimum takes into account `futureBlock`, and will omit any pending magnitude
     * diffs that will not be in effect as of `futureBlock`. NOTE that in order to get the true
     * minimum slashable stake as of some future block, `futureBlock` MUST be greater than block.number
     * @dev NOTE that `futureBlock` should be fewer than `DEALLOCATION_DELAY` blocks in the future,
     * or the values returned from this method may not be accurate due to deallocations.
     * @param operatorSet the operator set to query
     * @param operators the list of operators whose slashable stakes will be returned
     * @param strategies the strategies that each slashable stake corresponds to
     * @param futureBlock the block at which to get allocation information. Should be a future block.
     */
    function getMinimumSlashableStake(
        OperatorSet memory operatorSet,
        address[] memory operators,
        IStrategy[] memory strategies,
        uint32 futureBlock
    ) external view returns (uint256[][] memory slashableStake);

    /**
     * @notice Returns the current allocated stake, irrespective of the operator's slashable status for the operatorSet.
     * @param operatorSet the operator set to query
     * @param operators the operators to query
     * @param strategies the strategies to query
     */
    function getAllocatedStake(
        OperatorSet memory operatorSet,
        address[] memory operators,
        IStrategy[] memory strategies
    ) external view returns (uint256[][] memory slashableStake);

    /**
     * @notice Returns whether an operator is slashable by an operator set.
     * This returns true if the operator is registered or their slashableUntil block has not passed.
     * This is because even when operators are deregistered, they still remain slashable for a period of time.
     * @param operator the operator to check slashability for
     * @param operatorSet the operator set to check slashability for
     */
    function isOperatorSlashable(address operator, OperatorSet memory operatorSet)
        external
        view
        returns (bool);
}
