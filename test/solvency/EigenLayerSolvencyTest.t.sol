// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "../../src/adapters/EigenLayerWstETHAdapter.sol";
import "../../src/adapters/IsolatedEigenLayerVaultFactory.sol";
import "../../src/adapters/IsolatedEigenLayerWstETHVault.sol";
import "../../src/queues/EigenLayerWithdrawalQueue.sol";

import "../../src/strategies/RatiosStrategy.sol";
import "../../src/utils/Claimer.sol";
import "../../src/vaults/MultiVault.sol";

import "../Constants.sol";
import "../RandomLib.sol";
import "../mocks/MockAVS.sol";

import "./IAllocationManager.sol";

contract EigenLayerSolvencyTest is Test {
    using RandomLib for RandomLib.Storage;

    uint256 public constant DELAY = 1 days; // blocks
    uint256 public constant ITERATIONS = 100;

    RandomLib.Storage internal rnd = RandomLib.Storage(uint256(keccak256("EigenLayerSolvencyTest")));

    address public user = vm.createWallet("user").addr;
    address public vaultAdmin = vm.createWallet("vault-admin").addr;
    address public vaultProxyAdmin = vm.createWallet("vault-proxy-admin").addr;
    address public deployer = vm.createWallet("deployer").addr;
    address public curator = vm.createWallet("curator").addr;

    struct Deployment {
        MultiVault vault;
        address strategy;
        address claimer;
        address elVaultSingleton;
        address elQueueSingleton;
        address elFactory;
        address elAdapter;
        address avs;
    }

    struct Statistics {
        uint256 totalDeposits;
        uint256 totalClaims;
        uint256 totalSlashed;
    }

    Statistics public stats;

    function deployForAsset(address asset) internal returns (Deployment memory $) {
        bytes32 salt = bytes32(rnd.rand());
        address singleton = address(new MultiVault{salt: salt}("MultiVault", 1));
        $.vault = MultiVault(
            address(
                new TransparentUpgradeableProxy{salt: salt}(
                    singleton, vaultProxyAdmin, new bytes(0)
                )
            )
        );

        $.strategy = address(new RatiosStrategy{salt: salt}());
        $.claimer = address(new Claimer{salt: salt}());
        IMultiVault.InitParams memory initParams;
        initParams.admin = vaultAdmin;
        initParams.limit = type(uint256).max;
        initParams.asset = asset;
        initParams.name = "MultiVault";
        initParams.symbol = "MVLT";
        initParams.depositStrategy = $.strategy;
        initParams.withdrawalStrategy = $.strategy;
        initParams.rebalanceStrategy = $.strategy;
        if (asset == Constants.WSTETH()) {
            $.elVaultSingleton =
                address(new IsolatedEigenLayerWstETHVault{salt: salt}(Constants.WSTETH()));
            $.elQueueSingleton = address(
                new EigenLayerWithdrawalQueue{salt: salt}(
                    $.claimer, Constants.EL_DELEGATION_MANAGER()
                )
            );
            $.elFactory = address(
                new IsolatedEigenLayerVaultFactory{salt: salt}(
                    Constants.EL_DELEGATION_MANAGER(),
                    $.elVaultSingleton,
                    $.elQueueSingleton,
                    vaultProxyAdmin
                )
            );
            $.elAdapter = address(
                new EigenLayerWstETHAdapter{salt: salt}(
                    $.elFactory,
                    address($.vault),
                    IStrategyManager(Constants.EL_STRATEGY_MANAGER()),
                    IRewardsCoordinator(Constants.EL_REWARDS_COORDINATOR()),
                    Constants.WSTETH()
                )
            );
        } else {
            $.elVaultSingleton = address(new IsolatedEigenLayerVault{salt: salt}());
            $.elQueueSingleton = address(
                new EigenLayerWithdrawalQueue{salt: salt}(
                    $.claimer, Constants.EL_DELEGATION_MANAGER()
                )
            );
            $.elFactory = address(
                new IsolatedEigenLayerVaultFactory{salt: salt}(
                    Constants.EL_DELEGATION_MANAGER(),
                    $.elVaultSingleton,
                    $.elQueueSingleton,
                    vaultProxyAdmin
                )
            );
            $.elAdapter = address(
                new EigenLayerAdapter{salt: salt}(
                    $.elFactory,
                    address($.vault),
                    IStrategyManager(Constants.EL_STRATEGY_MANAGER()),
                    IRewardsCoordinator(Constants.EL_REWARDS_COORDINATOR())
                )
            );
        }
        initParams.eigenLayerAdapter = $.elAdapter;
        $.vault.initialize(initParams);

        ISignatureUtils.SignatureWithExpiry memory signature;
        (address isolatedVault,) = IsolatedEigenLayerVaultFactory($.elFactory).getOrCreate(
            address($.vault),
            Constants.getELStrategyForAssets(asset),
            Constants.EL_OPERATOR(),
            abi.encode(signature, salt)
        );

        vm.startPrank(initParams.admin);
        $.vault.grantRole($.vault.ADD_SUBVAULT_ROLE(), initParams.admin);
        $.vault.addSubvault(isolatedVault, IMultiVaultStorage.Protocol.EIGEN_LAYER);

        $.vault.grantRole(
            RatiosStrategy($.strategy).RATIOS_STRATEGY_SET_RATIOS_ROLE(), initParams.admin
        );
        address[] memory x = new address[](1);
        x[0] = isolatedVault;
        IRatiosStrategy.Ratio[] memory y = new IRatiosStrategy.Ratio[](1);
        y[0] = IRatiosStrategy.Ratio({minRatioD18: 0.9 ether, maxRatioD18: 0.95 ether});
        RatiosStrategy($.strategy).setRatios(address($.vault), x, y);
        $.avs = prepareSlashing($);
        vm.stopPrank();
    }

    function allocateWstETH() internal {
        address stETHSource = 0x66b25CFe6B9F0e61Bd80c4847225Baf4EE6Ba0A2;
        vm.startPrank(stETHSource);
        ISTETH steth = ISTETH(Constants.STETH());
        IWSTETH wsteth = IWSTETH(Constants.WSTETH());
        uint256 amount = steth.balanceOf(stETHSource);
        steth.approve(address(wsteth), type(uint256).max);
        amount = wsteth.wrap(amount);
        wsteth.transfer(user, amount);
        vm.stopPrank();
    }

    function deposit(Deployment memory $, uint256 assets) internal {
        address asset = $.vault.asset();
        if (asset == Constants.WSTETH()) {
            if (IERC20(asset).balanceOf(user) < assets) {
                allocateWstETH();
            }
        } else {
            deal(asset, user, assets);
        }
        vm.startPrank(user);
        IERC20(asset).approve(address($.vault), assets);
        $.vault.deposit(assets, user);
        stats.totalDeposits += assets;
        vm.stopPrank();
    }

    function redeem(Deployment memory $, uint256 shares) internal returns (uint256) {
        IERC20 asset = IERC20($.vault.asset());
        uint256 balanceBefore = asset.balanceOf(user);
        EigenLayerWithdrawalQueue wq =
            EigenLayerWithdrawalQueue($.vault.subvaultAt(0).withdrawalQueue);
        vm.startPrank(user);
        try $.vault.redeem(shares, user, user) returns (uint256) {
            vm.stopPrank();
            return asset.balanceOf(user) - balanceBefore;
        } catch {
            vm.stopPrank();
            (, uint256[] memory withdrawals,) = wq.getAccountData(user, 20, 0, 0, 0);
            assertEq(withdrawals.length, wq.MAX_WITHDRAWALS(), "Invalid state (redeem error)");
            return 0;
        }
    }

    function claim(Deployment memory $, uint256 maxAssets) internal returns (uint256) {
        vm.prank(user);
        uint256 assets = Claimer($.claimer).multiAcceptAndClaim(
            address($.vault), new uint256[](1), new uint256[][](1), user, maxAssets
        );
        vm.stopPrank();
        return assets;
    }

    function prepareSlashing(Deployment memory $) internal returns (address avs) {
        address isolatedVault = $.vault.subvaultAt(0).vault;
        (, address elStrategy, address elOperator,) =
            IsolatedEigenLayerVaultFactory($.elFactory).instances(isolatedVault);
        IAllocationManager allocationManager = IAllocationManager(Constants.EL_ALLOCATION_MANAGER());

        avs = address(new MockAVS());
        address[] memory strategies = new address[](1);
        strategies[0] = elStrategy;

        vm.startPrank(avs);
        IAllocationManager(allocationManager).updateAVSMetadataURI(avs, "test-avs-metadata-uri");
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
        IAllocationManager(allocationManager).setAllocationDelay(elOperator, uint32(DELAY / 5));
        vm.roll(block.number + DELAY);
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
            vm.stopPrank();
            vm.roll(block.number + DELAY);
        }
    }

    function slash(Deployment memory $, uint256 shares) internal {
        address isolatedVault = $.vault.subvaultAt(0).vault;
        (, address elStrategy, address elOperator, address wq) =
            IsolatedEigenLayerVaultFactory($.elFactory).instances(isolatedVault);
        address[] memory strategies = new address[](1);
        strategies[0] = elStrategy;
        uint256[] memory wadsToSlash = new uint256[](1);
        wadsToSlash[0] = shares;

        uint256 stakedBeforeSlashing = $.vault.totalAssets();
        uint256 pendingBefore = EigenLayerWithdrawalQueue(wq).pendingAssetsOf(user);
        vm.startPrank(address($.avs));
        IAllocationManager(Constants.EL_ALLOCATION_MANAGER()).slashOperator(
            $.avs,
            IAllocationManager.SlashingParams({
                operator: elOperator,
                operatorSetId: 0,
                strategies: strategies,
                wadsToSlash: wadsToSlash,
                description: "test"
            })
        );
        stats.totalSlashed += stakedBeforeSlashing - $.vault.totalAssets();
        stats.totalSlashed += pendingBefore - EigenLayerWithdrawalQueue(wq).pendingAssetsOf(user);
        vm.stopPrank();
    }

    function(Deployment memory)[4] internal transitions =
        [random_deposit, random_redeem, random_claim, random_slash];

    function random_deposit(Deployment memory $) internal {
        uint256 assets = rnd.randInt(1 gwei, 100 ether);
        deposit($, assets);
    }

    function random_redeem(Deployment memory $) internal {
        if ($.vault.totalSupply() == 0) {
            return;
        }
        uint256 shares = rnd.randInt(1, $.vault.totalSupply());
        stats.totalClaims += redeem($, shares);
    }

    function random_claim(Deployment memory $) internal {
        uint256 maxAssets = rnd.randBool() ? 1 ether : type(uint256).max;
        stats.totalClaims += claim($, maxAssets);
    }

    function random_slash(Deployment memory $) internal {
        uint256 stakedAssets = EigenLayerAdapter($.elAdapter).stakedAt($.vault.subvaultAt(0).vault);
        if (stakedAssets == 0) {
            return;
        }
        uint256 share = rnd.randInt(1, 0.5 ether);
        slash($, share);
    }

    function finalize(Deployment memory $) internal {
        uint256 lp = $.vault.balanceOf(user);
        if (lp != 0) {
            vm.roll(block.number + DELAY);
            stats.totalClaims += redeem($, lp);
        }

        vm.roll(block.number + DELAY);
        stats.totalClaims += claim($, type(uint256).max);
    }

    function checkFinalState(Deployment memory $) internal view {
        assertEq($.vault.totalSupply(), 0, "Invalid total supply state (finalize)");
        assertLe($.vault.totalAssets(), 1 gwei, "Invalid total assets state (finalize)");
        string memory s = string(
            abi.encodePacked(
                "Final state: deposits: ",
                vm.toString(stats.totalDeposits),
                ", claims: ",
                vm.toString(stats.totalClaims),
                ", slashed: ",
                vm.toString(stats.totalSlashed)
            )
        );
        assertApproxEqAbs(stats.totalDeposits, stats.totalClaims + stats.totalSlashed, 1 gwei, s);
    }

    function runTestWithSlashing(address asset) public {
        Deployment memory $ = deployForAsset(asset);

        uint256 iterations = ITERATIONS;
        for (uint256 i = 0; i < iterations; i++) {
            uint256 transitionIndex = rnd.rand() % transitions.length;
            transitions[transitionIndex]($);
        }

        finalize($);
        checkFinalState($);
    }

    function testEigenLayerWithSlashing_WstETH() external {
        // rnd = RandomLib.Storage(seed_);
        runTestWithSlashing(Constants.WSTETH());
    }

    function testEigenLayerWithSlashing_EIGEN() external {
        // rnd = RandomLib.Storage(seed_);
        runTestWithSlashing(Constants.EIGEN());
    }
}
