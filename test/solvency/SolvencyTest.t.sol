// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../../scripts/mainnet/FactoryDeploy.sol";
import "../../src/VaultControl.sol";
import "../../src/interfaces/vaults/IVaultControl.sol";
import "../BaseTest.sol";

import "../mocks/MockRewardToken.sol";

import {MockDefaultStakerRewards} from "../mocks/MockDefaultStakerRewards.sol";
import {IDefaultStakerRewards} from
    "@symbiotic/rewards/interfaces/defaultStakerRewards/IDefaultStakerRewards.sol";
import {IStakerRewards} from "@symbiotic/rewards/interfaces/stakerRewards/IStakerRewards.sol";

import {NetworkRegistry} from "@symbiotic/core/contracts/NetworkRegistry.sol";
import {NetworkMiddlewareService} from
    "@symbiotic/core/contracts/service/NetworkMiddlewareService.sol";

contract SolvencyTest is BaseTest {
    using SafeERC20 for IERC20;

    uint256 constant ITER = 50;
    uint256 constant MAX_ALLOWED_ERROR = ITER;
    uint256 seed = 42;

    address immutable admin = makeAddr("admin");
    address immutable vaultOwner = makeAddr("vaultOwner");
    address immutable vaultAdmin = makeAddr("vaultAdmin");
    address immutable proxyAdmin = makeAddr("proxyAdmin");
    address immutable mellowVaultAdmin = makeAddr("mellowVaultAdmin");
    address immutable burner = makeAddr("burner");
    address immutable network = makeAddr("network");

    uint48 epochDuration = 3600;

    MockRewardToken rewardToken =
        new MockRewardToken("MockRewardTokenName", "MockRewardTokenSymbol", 1e6 ether);

    ISymbioticVault symbioticVault;
    MellowSymbioticVault mellowSymbioticVault;

    uint256 limit;
    address[] depositors;
    uint256[] depositedAmounts;
    uint256[] claimedAmounts;
    uint256[] slashedAmounts;

    uint256 cumulativeSlashedAmounts;

    EthWrapper depositWrapper = new EthWrapper(HOLESKY_WETH, HOLESKY_WSTETH, HOLESKY_STETH);
    address[] depositWrapperTokens = [
        depositWrapper.ETH(),
        depositWrapper.wstETH(),
        depositWrapper.stETH(),
        depositWrapper.WETH()
    ];

    function()[] transitions = [
        transitionRandomDeposit,
        transitionRandomWithdrawal,
        transitionRandomLimitSet,
        transitionRandomClaim,
        transitionRandomSlashing,
        transitionRandomFarm,
        transitionPushIntoSymbiotic,
        transitionEpochSkip
    ];

    uint256 nTransitions = transitions.length;

    MockDefaultStakerRewards defaultStakerRewards;

    struct Position {
        uint256 shares;
        uint256 assets;
        uint256 staked;
        uint256 claimable;
        uint256 pending;
        uint256 pendingNext;
    }

    struct SystemSnapshot {
        // Symbiotic Vault specific:
        uint256 symbioticActiveStake;
        uint256 symbioticActiveShares;
        uint256 symbioticTotalStake;
        uint256 mellowActiveStake;
        uint256 mellowActiveShares;
        uint256 mellowTotalStake;
        uint48 timestamp;
        uint256 epoch;
        uint256 symbioticWithdrawals;
        uint256 symbioticWithdrawalsNext;
        uint256 mellowWithdrawals;
        uint256 mellowWithdrawalsNext;
        // MellowSymbioticVault specific:
        uint256 mellowTotalSupply;
        uint256 mellowTotalAssets;
        address queue;
        // SymbioticWithdrawalQueue specific:
        Position[] positions;
    }

    function getSnapshot() internal view returns (SystemSnapshot memory s) {
        s.mellowTotalSupply = mellowSymbioticVault.totalSupply();
        s.mellowTotalAssets = mellowSymbioticVault.totalAssets();
        s.queue = address(mellowSymbioticVault.withdrawalQueue());

        s.positions = getUserPositions();

        s.symbioticActiveStake = symbioticVault.activeStake();
        s.symbioticActiveShares = symbioticVault.activeShares();

        s.mellowActiveStake = symbioticVault.activeBalanceOf(address(mellowSymbioticVault));
        s.mellowActiveShares = symbioticVault.activeSharesOf(address(mellowSymbioticVault));

        s.timestamp = uint48(block.timestamp);
        s.epoch = symbioticVault.currentEpoch();

        s.symbioticWithdrawals = symbioticVault.withdrawals(s.epoch);
        s.symbioticWithdrawalsNext = symbioticVault.withdrawals(s.epoch + 1);
        s.symbioticTotalStake =
            s.symbioticActiveStake + s.symbioticWithdrawals + s.symbioticWithdrawalsNext;

        s.mellowWithdrawals = symbioticVault.withdrawalsOf(s.epoch, address(s.queue));
        s.mellowWithdrawalsNext = symbioticVault.withdrawalsOf(s.epoch + 1, address(s.queue));
        s.mellowTotalStake = s.mellowActiveStake + s.mellowWithdrawals + s.mellowWithdrawalsNext;
    }

    function setUp() external {
        // logic below is used to prevent STAKE_LIMIT error in stETH contract
        bytes32 slot_ = 0xa3678de4a579be090bed1177e0a24f77cc29d181ac22fd7688aca344d8938015;
        bytes32 value = vm.load(HOLESKY_STETH, slot_);
        bytes32 new_value = bytes32(uint256(value) & type(uint160).max); // nullify maxStakeLimit
        vm.store(HOLESKY_STETH, slot_, new_value);
    }

    function deploy(uint256 _limit, uint256 _symbioticLimit) public {
        symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParamsExtended({
                    vaultOwner: vaultOwner,
                    vaultAdmin: vaultAdmin,
                    burner: burner,
                    epochDuration: epochDuration,
                    asset: HOLESKY_WSTETH,
                    isDepositLimit: false,
                    depositLimit: _symbioticLimit
                })
            )
        );

        limit = _limit;
        IMellowSymbioticVaultFactory.InitParams memory initParams = IMellowSymbioticVaultFactory
            .InitParams({
            proxyAdmin: proxyAdmin,
            limit: limit,
            symbioticCollateral: address(HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL),
            symbioticVault: address(symbioticVault),
            admin: admin,
            depositPause: false,
            withdrawalPause: false,
            depositWhitelist: false,
            name: "MellowSymbioticVault",
            symbol: "MSV"
        });

        FactoryDeploy.FactoryDeployParams memory factoryDeployParams = FactoryDeploy
            .FactoryDeployParams({
            factory: address(0),
            singletonName: "MellowSymbioticVault",
            singletonVersion: 1,
            setFarmRoleHoler: mellowVaultAdmin,
            setLimitRoleHolder: mellowVaultAdmin,
            pauseWithdrawalsRoleHolder: mellowVaultAdmin,
            unpauseWithdrawalsRoleHolder: mellowVaultAdmin,
            pauseDepositsRoleHolder: mellowVaultAdmin,
            unpauseDepositsRoleHolder: mellowVaultAdmin,
            setDepositWhitelistRoleHolder: mellowVaultAdmin,
            setDepositorWhitelistStatusRoleHolder: mellowVaultAdmin,
            initParams: initParams
        });

        (IMellowSymbioticVault iMellowSymbioticVault, FactoryDeploy.FactoryDeployParams memory __) =
            FactoryDeploy.deploy(factoryDeployParams);
        mellowSymbioticVault = MellowSymbioticVault(address(iMellowSymbioticVault));

        defaultStakerRewards = createDefaultStakerRewards();

        vm.startPrank(admin);
        mellowSymbioticVault.grantRole(SET_FARM_ROLE, admin);

        IMellowSymbioticVaultStorage.FarmData memory farmData = IMellowSymbioticVaultStorage
            .FarmData({
            rewardToken: address(rewardToken),
            symbioticFarm: address(defaultStakerRewards),
            distributionFarm: makeAddr("distributionFarm"),
            curatorTreasury: makeAddr("curatorTreasury"),
            curatorFeeD6: 0
        });
        mellowSymbioticVault.setFarm(1, farmData);

        vm.stopPrank();
    }

    function runSolvencyAllTransitionsForSeed(uint256 seed_) internal {
        seed = seed_;
        deploy(1e8 ether, 1e16 ether);

        addRandomUser();

        for (uint256 i = 0; i < ITER; i++) {
            randomTransition();
        }

        finilizeTest();
        finalValidation();
    }

    function testSolvencyAllTransitions42() external {
        runSolvencyAllTransitionsForSeed(42);
    }

    function testSolvencyAllTransitions43() external {
        runSolvencyAllTransitionsForSeed(43);
    }

    function testSolvencyAllTransitions44() external {
        runSolvencyAllTransitionsForSeed(44);
    }

    function testSolvencyAllTransitions45() external {
        runSolvencyAllTransitionsForSeed(45);
    }

    function testSolvencyAllTransitions46() external {
        runSolvencyAllTransitionsForSeed(46);
    }

    function testSolvencyAllTransitions47() external {
        runSolvencyAllTransitionsForSeed(47);
    }

    function testSolvencyAllTransitions48() external {
        runSolvencyAllTransitionsForSeed(48);
    }

    function testSolvencyAllTransitions142() external {
        runSolvencyAllTransitionsForSeed(142);
    }

    function testSolvencyAllTransitions143() external {
        runSolvencyAllTransitionsForSeed(143);
    }

    function testSolvencyAllTransitions144() external {
        runSolvencyAllTransitionsForSeed(144);
    }

    function testSolvencyAllTransitions145() external {
        runSolvencyAllTransitionsForSeed(145);
    }

    function testSolvencyAllTransitions146() external {
        runSolvencyAllTransitionsForSeed(146);
    }

    function testSolvencyAllTransitions147() external {
        runSolvencyAllTransitionsForSeed(147);
    }

    function testSolvencyAllTransitions148() external {
        runSolvencyAllTransitionsForSeed(148);
    }

    function testSolvencyRandomTransitionSubset() external {
        deploy(1e8 ether, 1e16 ether);

        addRandomUser();
        uint256 transitionSubset = _randInt(1, 2 ** nTransitions - 1);
        for (uint256 i = 0; i < ITER; i++) {
            randomTransition(transitionSubset);
        }

        finilizeTest();
        finalValidation();
    }

    function testFuzz_TransitonBitmask(
        uint256 iter,
        uint256 _limit,
        uint256 _symbioticLimit,
        uint256 transitionSubset
    ) external {
        deploy(_limit, _symbioticLimit);

        addRandomUser();
        for (uint256 i = 0; i < iter; i++) {
            randomTransition(transitionSubset);
        }

        finilizeTest();
        finalValidation();
    }

    function testFuzz_TrasitionList(
        uint256[] memory transitionIndexes,
        uint256 _limit,
        uint256 _symbioticLimit
    ) external {
        deploy(_limit, _symbioticLimit);

        addRandomUser();
        for (uint256 i = 0; i < transitionIndexes.length; i++) {
            transitionByIndex(transitionIndexes[i]);
        }

        finilizeTest();
        finalValidation();
    }

    function addRandomUser() internal returns (address) {
        address user = random_address();
        depositors.push(user);
        depositedAmounts.push(0);
        slashedAmounts.push(0);
        claimedAmounts.push(0);
        return user;
    }

    struct StackTransitionRandomDeposit {
        address user;
        uint256 amount;
        uint256 expectedVaultVaultIncrement;
        address depositToken;
        bool withDepositWrapper;
        bool withPlainEth;
    }

    function transitionRandomDeposit() internal {
        StackTransitionRandomDeposit memory s;

        if (random_bool()) {
            s.user = addRandomUser();
        } else {
            s.user = depositors[_randInt(0, depositors.length - 1)];
        }

        s.amount = calc_random_amount_d18();

        s.withDepositWrapper = random_bool();
        s.withPlainEth = false;
        if (s.withDepositWrapper) {
            uint256 depositTokenIndex = _randInt(0, depositWrapperTokens.length - 1);
            s.depositToken = depositWrapperTokens[depositTokenIndex];
            if (s.depositToken == depositWrapper.ETH()) {
                s.withPlainEth = true;
            }
        } else {
            s.depositToken = HOLESKY_WSTETH;
        }

        s.expectedVaultVaultIncrement = s.amount;
        if (s.depositToken != HOLESKY_WSTETH) {
            // eth == weth == steth = price * wsteth
            s.expectedVaultVaultIncrement = IWSTETH(HOLESKY_WSTETH).getWstETHByStETH(s.amount);
        }

        uint256 vaultValueBefore = mellowSymbioticVault.totalAssets();
        uint256 vaultSupplyBefore = mellowSymbioticVault.totalSupply();
        uint256 expectedVaultValueAfter = vaultValueBefore + s.expectedVaultVaultIncrement;
        uint256 expectedTotalSupplyAfter = vaultValueBefore == 0
            ? s.expectedVaultVaultIncrement
            : Math.mulDiv(expectedVaultValueAfter, vaultSupplyBefore, vaultValueBefore);

        assertEq(
            mellowSymbioticVault.previewDeposit(s.expectedVaultVaultIncrement),
            vaultValueBefore == 0
                ? s.expectedVaultVaultIncrement
                : Math.mulDiv(
                    s.expectedVaultVaultIncrement,
                    vaultSupplyBefore + 1,
                    vaultValueBefore + 1 // OZ ERC4626 logic
                ),
            "previewDeposit"
        );

        vm.startPrank(s.user);

        // an example of referral code
        address referral = address(bytes20(s.user) ^ bytes20("some-referral-logic"));
        bool isLimitOverflowExpected = expectedVaultValueAfter > mellowSymbioticVault.limit();

        if (s.withPlainEth) {
            deal(s.user, s.amount);
            if (isLimitOverflowExpected) {
                vm.expectRevert();
            }
            depositWrapper.deposit{value: s.amount}(
                s.depositToken, s.amount, address(mellowSymbioticVault), s.user, referral
            );
        } else {
            if (s.depositToken != HOLESKY_STETH) {
                if (s.depositToken == HOLESKY_WETH) {
                    deal(HOLESKY_WETH, s.amount); // to avoid OOF
                }
                deal(s.depositToken, s.user, s.amount);
            } else {
                deal(s.user, s.amount);
                ISTETH(HOLESKY_STETH).submit{value: s.amount}(address(0));
            }
            if (s.withDepositWrapper) {
                IERC20(s.depositToken).forceApprove(address(depositWrapper), s.amount);
                if (isLimitOverflowExpected) {
                    vm.expectRevert();
                }
                depositWrapper.deposit(
                    s.depositToken, s.amount, address(mellowSymbioticVault), s.user, referral
                );
            } else {
                IERC20(s.depositToken).forceApprove(address(mellowSymbioticVault), s.amount);
                if (isLimitOverflowExpected) {
                    vm.expectRevert();
                }
                mellowSymbioticVault.deposit(s.amount, s.user, referral);
            }
        }

        if (isLimitOverflowExpected) {
            vm.stopPrank();
            return;
        }

        uint256 vaultValueAfter = mellowSymbioticVault.totalAssets();
        uint256 vaultSupplyAfter = mellowSymbioticVault.totalSupply();

        assertEq(vaultValueAfter, expectedVaultValueAfter, "vaultValueAfter");
        // assertApproxEqAbs(vaultSupplyAfter, expectedTotalSupplyAfter, 1 gwei, "vaultSupplyAfter");

        depositedAmounts[_indexOf(s.user)] += s.expectedVaultVaultIncrement;

        vm.stopPrank();
    }

    function transitionRandomWithdrawal() internal {
        uint256 index = _randInt(0, depositors.length - 1);
        address user = depositors[index];
        uint256 amount = calc_random_amount_d18();
        vm.startPrank(user);

        uint256 pendingAssetsOf_ = mellowSymbioticVault.pendingAssetsOf(user);
        uint256 claimableAssetsOf_ = mellowSymbioticVault.claimableAssetsOf(user);

        uint256 availableAmount = depositedAmounts[index]
            - (slashedAmounts[index] + pendingAssetsOf_ + claimableAssetsOf_ + claimedAmounts[index]);

        uint256 maxWithdraw = mellowSymbioticVault.maxWithdraw(user);

        assertApproxEqAbs(
            maxWithdraw,
            availableAmount,
            MAX_ALLOWED_ERROR,
            "transitionRandomWithdrawal: maxWithdraw != availableAmount"
        );

        if (amount > maxWithdraw) {
            vm.expectRevert();
            mellowSymbioticVault.withdraw(amount, user, user);
        } else {
            mellowSymbioticVault.withdraw(amount, user, user);
        }
        vm.stopPrank();
    }

    function transitionRandomClaim() internal {
        uint256[] memory claimableAmounts = new uint256[](depositedAmounts.length);
        uint256 claimableAccounts = 0;
        for (uint256 i = 0; i < depositedAmounts.length; i++) {
            claimableAmounts[i] = mellowSymbioticVault.claimableAssetsOf(depositors[i]);
            if (claimableAmounts[i] > 0) {
                claimableAccounts++;
            }
        }

        if (claimableAccounts != 0 && random_bool()) {
            // successfull claim
            uint256 offset = _randInt(claimableAccounts - 1);
            uint256 index;
            for (uint256 i = 0; i < depositedAmounts.length; i++) {
                if (claimableAmounts[i] > 0) {
                    if (offset == 0) {
                        index = i;
                        break;
                    }
                    offset--;
                }
            }

            address user = depositors[index];
            uint256 claimableAmount = claimableAmounts[index];
            uint256 balanceBefore = IERC20(HOLESKY_WSTETH).balanceOf(user);

            uint256 claimingAmount = _randInt(claimableAmount * 2); // probably more than claimable
            uint256 expectedClaimedAmount = Math.min(claimingAmount, claimableAmount);

            vm.prank(user);
            uint256 returnedValue = mellowSymbioticVault.claim(user, user, claimingAmount);

            uint256 balanceAfter = IERC20(HOLESKY_WSTETH).balanceOf(user);
            assertEq(
                balanceAfter - balanceBefore,
                expectedClaimedAmount,
                "claimableAmounts (existing depositor)"
            );
            assertEq(returnedValue, expectedClaimedAmount, "returnedValue");

            vm.stopPrank();

            claimedAmounts[index] += returnedValue;
        } else if (depositors.length > claimableAccounts) {
            // empty claim for depositor

            address user;
            if (random_bool()) {
                uint256 offset = _randInt(depositors.length - claimableAccounts - 1);
                uint256 index = type(uint256).max;
                for (uint256 i = 0; i < depositedAmounts.length; i++) {
                    if (claimableAmounts[i] == 0) {
                        if (offset == 0) {
                            index = i;
                            break;
                        }
                        offset--;
                    }
                }
                user = depositors[index];
            } else {
                user = random_address();
            }

            uint256 claimingAmount = _randInt(mellowSymbioticVault.totalAssets() * 2);
            uint256 claimableAmount = 0;
            uint256 balanceBefore = IERC20(HOLESKY_WSTETH).balanceOf(user);

            uint256 expectedClaimedAmount = Math.min(claimingAmount, claimableAmount);

            vm.prank(user);
            uint256 returnedValue = mellowSymbioticVault.claim(user, user, claimingAmount);

            uint256 balanceAfter = IERC20(HOLESKY_WSTETH).balanceOf(user);
            assertEq(
                balanceAfter - balanceBefore,
                expectedClaimedAmount,
                "claimableAmounts (random user)"
            );
            assertEq(returnedValue, expectedClaimedAmount, "returnedValue");

            vm.stopPrank();
        }
    }

    function transitionRandomLimitSet() internal {
        uint256 newLimit = _randInt(mellowSymbioticVault.limit() + calc_random_amount_d18());
        vm.startPrank(admin);
        if (!mellowSymbioticVault.hasRole(SET_LIMIT_ROLE, admin)) {
            mellowSymbioticVault.grantRole(SET_LIMIT_ROLE, admin);
        }
        mellowSymbioticVault.setLimit(newLimit);
        vm.stopPrank();
    }

    function transitionPushIntoSymbiotic() internal {
        address user = depositors[_randInt(0, depositors.length - 1)];
        vm.startPrank(user);
        mellowSymbioticVault.pushIntoSymbiotic();
        vm.stopPrank();
    }

    function pendingWithdrawalsOf(SymbioticWithdrawalQueue queue, address user, uint256 epoch)
        internal
        view
        returns (uint256 pendingAssets)
    {
        (
            uint256 sharesToClaimPrev,
            uint256 sharesToClaim,
            uint256 claimableAssets,
            uint256 claimEpoch
        ) = queue.getAccountData(user);

        if (epoch != claimEpoch && epoch + 1 != claimEpoch) {
            return 0;
        }

        uint256 shares = epoch == claimEpoch ? sharesToClaim : sharesToClaimPrev;
        if (shares == 0) {
            return 0;
        }
        return Math.mulDiv(
            shares,
            symbioticVault.withdrawalsOf(epoch, address(queue)),
            queue.getEpochData(epoch).sharesToClaim
        );
    }

    function getUserPositions() internal view returns (Position[] memory positions) {
        positions = new Position[](depositors.length);
        SymbioticWithdrawalQueue queue =
            SymbioticWithdrawalQueue(address(mellowSymbioticVault.withdrawalQueue()));
        uint256 epoch = symbioticVault.currentEpoch();
        uint256 totalAssets = mellowSymbioticVault.totalAssets();
        uint256 stakedAssets = symbioticVault.activeBalanceOf(address(mellowSymbioticVault));
        for (uint256 i = 0; i < depositors.length; i++) {
            address user = depositors[i];
            positions[i] = Position({
                shares: mellowSymbioticVault.balanceOf(user),
                assets: mellowSymbioticVault.maxWithdraw(user),
                staked: 0,
                claimable: mellowSymbioticVault.claimableAssetsOf(user),
                pending: pendingWithdrawalsOf(queue, user, epoch),
                pendingNext: pendingWithdrawalsOf(queue, user, epoch + 1)
            });
            positions[i].staked =
                totalAssets == 0 ? 0 : Math.mulDiv(positions[i].assets, stakedAssets, totalAssets);
        }
    }

    struct TransitionRandomSlashingStack {
        SystemSnapshot before_;
        SystemSnapshot after_;
        uint256 slashingAmount;
        uint48 captureTimestamp;
        uint256 symbioticActiveStakeSlashed;
        uint256 symbioticWithdrawalsSlashed;
        uint256 symbioticWithdrawalsNextSlashed;
        uint256 mellowActiveStakeSlashed;
        uint256 mellowWithdrawalsSlashed;
        uint256 mellowWithdrawalsNextSlashed;
    }

    function transitionRandomSlashing() internal {
        TransitionRandomSlashingStack memory s;
        s.before_ = getSnapshot();

        // scenario for current epoch
        if (random_bool() || symbioticVault.currentEpoch() == 0) {
            s.captureTimestamp = s.before_.timestamp;

            assertEq(
                symbioticVault.epochAt(s.captureTimestamp),
                s.before_.epoch,
                "transitionRandomSlashing (current epoch): epochAt(captureTimestamp) != currentEpoch"
            );

            uint256 mellowSlashableStake =
                s.before_.mellowActiveStake + s.before_.mellowWithdrawalsNext;
            uint256 symbioticSlashableStake =
                s.before_.symbioticActiveStake + s.before_.symbioticWithdrawalsNext;

            if (symbioticSlashableStake == 0) {
                // nothing to slash -> early exit
                return;
            }

            s.slashingAmount = _randInt(1, symbioticSlashableStake);

            vm.prank(symbioticVault.slasher());
            symbioticVault.onSlash(s.slashingAmount, s.captureTimestamp);

            s.after_ = getSnapshot();

            uint256 actualSlashedAmount =
                s.before_.symbioticTotalStake - s.after_.symbioticTotalStake;

            assertEq(
                actualSlashedAmount,
                s.slashingAmount,
                "transitionRandomSlashing (current epoch): actual slashedAmount != requested slashingAmount"
            );

            s.symbioticActiveStakeSlashed = Math.mulDiv(
                s.slashingAmount, s.before_.symbioticActiveStake, symbioticSlashableStake
            );

            s.symbioticWithdrawalsSlashed = 0; // no slashing for current epoch
            s.symbioticWithdrawalsNextSlashed = s.slashingAmount - s.symbioticActiveStakeSlashed;

            // expected values. Maximal error ~ 1 wei
            s.mellowActiveStakeSlashed = s.before_.mellowActiveStake == 0
                ? 0
                : Math.mulDiv(
                    s.before_.mellowActiveStake,
                    s.symbioticActiveStakeSlashed,
                    s.before_.symbioticActiveStake,
                    Math.Rounding.Ceil
                );

            s.mellowWithdrawalsSlashed = 0; // no slashing for current epoch
            s.mellowWithdrawalsNextSlashed = s.before_.mellowWithdrawalsNext == 0
                ? 0
                : Math.mulDiv(
                    s.before_.mellowWithdrawalsNext,
                    s.symbioticWithdrawalsNextSlashed,
                    s.before_.symbioticWithdrawalsNext,
                    Math.Rounding.Ceil
                );

            assertEq(
                s.before_.mellowWithdrawals,
                s.after_.mellowWithdrawals + s.mellowWithdrawalsSlashed,
                "transitionRandomSlashing (current epoch): mellowWithdrawals"
            );
            assertEq(
                s.before_.mellowWithdrawalsNext,
                s.after_.mellowWithdrawalsNext + s.mellowWithdrawalsNextSlashed,
                "transitionRandomSlashing (current epoch): mellowWithdrawalsNext"
            );

            for (uint256 i = 0; i < depositors.length; i++) {
                Position memory position = s.before_.positions[i];
                {
                    // rounding up
                    uint256 slashed = position.pendingNext == 0
                        ? 0
                        : Math.mulDiv(
                            position.pendingNext,
                            s.mellowWithdrawalsNextSlashed,
                            s.before_.mellowWithdrawalsNext,
                            Math.Rounding.Ceil
                        );
                    slashedAmounts[i] += slashed;
                    assertApproxEqAbs(
                        s.before_.positions[i].pendingNext,
                        s.after_.positions[i].pendingNext + slashed,
                        1,
                        "transitionRandomSlashing (current epoch): pendingNext"
                    );
                }
                {
                    // rounding up
                    uint256 slashed = position.staked == 0
                        ? 0
                        : Math.mulDiv(
                            position.staked,
                            s.mellowActiveStakeSlashed,
                            s.before_.mellowActiveStake,
                            Math.Rounding.Ceil
                        );
                    slashedAmounts[i] += slashed;
                    assertApproxEqAbs(
                        s.before_.positions[i].staked,
                        s.after_.positions[i].staked + slashed,
                        1,
                        "transitionRandomSlashing (current epoch): staked"
                    );
                    assertApproxEqAbs(
                        s.before_.positions[i].assets,
                        s.after_.positions[i].assets + slashed,
                        1,
                        "transitionRandomSlashing (current epoch): assets"
                    );
                }
            }
        } else {
            // scenario for previous epoch
            s.captureTimestamp = s.before_.timestamp - epochDuration;

            assertEq(
                symbioticVault.epochAt(s.captureTimestamp) + 1,
                s.before_.epoch,
                "transitionRandomSlashing (previous epoch): epochAt(captureTimestamp) + 1 != currentEpoch"
            );

            uint256 mellowSlashableStake = s.before_.mellowActiveStake + s.before_.mellowWithdrawals
                + s.before_.mellowWithdrawalsNext;
            uint256 symbioticSlashableStake = s.before_.symbioticActiveStake
                + s.before_.symbioticWithdrawals + s.before_.symbioticWithdrawalsNext;

            if (symbioticSlashableStake == 0) {
                // nothing to slash -> early exit
                return;
            }

            s.slashingAmount = _randInt(1, symbioticSlashableStake);

            vm.prank(symbioticVault.slasher());
            symbioticVault.onSlash(s.slashingAmount, s.captureTimestamp);

            s.after_ = getSnapshot();

            uint256 actualSlashedAmount =
                s.before_.symbioticTotalStake - s.after_.symbioticTotalStake;

            assertEq(
                actualSlashedAmount,
                s.slashingAmount,
                "transitionRandomSlashing (previous epoch): actual slashedAmount != requested slashingAmount"
            );

            s.symbioticActiveStakeSlashed = Math.mulDiv(
                s.slashingAmount, s.before_.symbioticActiveStake, symbioticSlashableStake
            );

            s.symbioticWithdrawalsNextSlashed = Math.mulDiv(
                s.slashingAmount, s.before_.symbioticWithdrawalsNext, symbioticSlashableStake
            );

            s.symbioticWithdrawalsSlashed =
                s.slashingAmount - s.symbioticActiveStakeSlashed - s.symbioticWithdrawalsNextSlashed;

            if (s.symbioticWithdrawalsSlashed > s.before_.symbioticWithdrawals) {
                s.symbioticWithdrawalsNextSlashed +=
                    s.symbioticWithdrawalsSlashed - s.before_.symbioticWithdrawals;
                s.symbioticWithdrawalsSlashed = s.before_.symbioticWithdrawals;
            }

            // expected values. Maximal error ~ 1 wei
            s.mellowActiveStakeSlashed = s.before_.mellowActiveStake == 0
                ? 0
                : Math.mulDiv(
                    s.before_.mellowActiveStake,
                    s.symbioticActiveStakeSlashed,
                    s.before_.symbioticActiveStake,
                    Math.Rounding.Ceil
                );

            s.mellowWithdrawalsSlashed = s.mellowWithdrawalsSlashed = s.before_.mellowWithdrawals
                == 0
                ? 0
                : Math.mulDiv(
                    s.before_.mellowWithdrawals,
                    s.symbioticWithdrawalsSlashed,
                    s.before_.symbioticWithdrawals,
                    Math.Rounding.Ceil
                );
            s.mellowWithdrawalsNextSlashed = s.before_.mellowWithdrawalsNext == 0
                ? 0
                : Math.mulDiv(
                    s.before_.mellowWithdrawalsNext,
                    s.symbioticWithdrawalsNextSlashed,
                    s.before_.symbioticWithdrawalsNext,
                    Math.Rounding.Ceil
                );

            assertEq(
                s.before_.mellowWithdrawals,
                s.after_.mellowWithdrawals + s.mellowWithdrawalsSlashed,
                "transitionRandomSlashing (previous epoch): mellowWithdrawals"
            );
            assertEq(
                s.before_.mellowWithdrawalsNext,
                s.after_.mellowWithdrawalsNext + s.mellowWithdrawalsNextSlashed,
                "transitionRandomSlashing (previous epoch): mellowWithdrawalsNext"
            );

            for (uint256 i = 0; i < depositors.length; i++) {
                Position memory position = s.before_.positions[i];
                {
                    // rounding up
                    uint256 slashed = position.pending == 0
                        ? 0
                        : Math.mulDiv(
                            position.pending,
                            s.mellowWithdrawalsSlashed,
                            s.before_.mellowWithdrawals,
                            Math.Rounding.Ceil
                        );
                    slashedAmounts[i] += slashed;
                    assertApproxEqAbs(
                        position.pending,
                        s.after_.positions[i].pending + slashed,
                        1,
                        "transitionRandomSlashing (previous epoch): pending"
                    );
                }
                {
                    // rounding up
                    uint256 slashed = position.pendingNext == 0
                        ? 0
                        : Math.mulDiv(
                            position.pendingNext,
                            s.mellowWithdrawalsNextSlashed,
                            s.before_.mellowWithdrawalsNext,
                            Math.Rounding.Ceil
                        );
                    slashedAmounts[i] += slashed;
                    assertApproxEqAbs(
                        position.pendingNext,
                        s.after_.positions[i].pendingNext + slashed,
                        1,
                        "transitionRandomSlashing (previous epoch): pendingNext"
                    );
                }
                {
                    // rounding up
                    uint256 slashed = position.staked == 0
                        ? 0
                        : Math.mulDiv(
                            position.staked,
                            s.mellowActiveStakeSlashed,
                            s.before_.mellowActiveStake,
                            Math.Rounding.Ceil
                        );
                    slashedAmounts[i] += slashed;

                    assertApproxEqAbs(
                        s.before_.positions[i].staked,
                        s.after_.positions[i].staked + slashed,
                        1,
                        "transitionRandomSlashing (previous epoch): staked"
                    );
                    assertApproxEqAbs(
                        s.before_.positions[i].assets,
                        s.after_.positions[i].assets + slashed,
                        1,
                        "transitionRandomSlashing (previous epoch): assets"
                    );
                }
            }
        }

        cumulativeSlashedAmounts += s.slashingAmount;
    }

    function transitionRandomFarm() internal {
        uint256 distributeAmount = _randInt(1, 1e18);

        // totalDistributedReward += distributeAmount;
        bytes memory data = abi.encode(block.timestamp, 0, "", "");

        vm.prank(network);
        defaultStakerRewards.distributeRewards(
            network, address(rewardToken), distributeAmount, data
        );
    }

    function createDefaultStakerRewards() internal returns (MockDefaultStakerRewards) {
        SymbioticHelper.SymbioticDeployment memory deployment =
            symbioticHelper.getSymbioticDeployment();
        defaultStakerRewards = new MockDefaultStakerRewards(
            deployment.vaultFactory, deployment.networkRegistry, deployment.networkMiddlewareService
        );
        IDefaultStakerRewards.InitParams memory params = IDefaultStakerRewards.InitParams({
            vault: address(symbioticVault),
            adminFee: 0,
            defaultAdminRoleHolder: vaultAdmin,
            adminFeeClaimRoleHolder: vaultAdmin,
            adminFeeSetRoleHolder: vaultAdmin
        });

        defaultStakerRewards.initialize(params);

        _registerNetwork(network, network);

        uint256 amount = 100000 * 1e18;
        rewardToken.transfer(network, 100000 ether);
        vm.startPrank(network);
        rewardToken.approve(address(defaultStakerRewards), type(uint256).max);

        IERC20(rewardToken).safeIncreaseAllowance(address(network), amount);
        IERC20(rewardToken).safeIncreaseAllowance(address(defaultStakerRewards), amount);
        vm.stopPrank();

        return defaultStakerRewards;
    }

    function _registerNetwork(address user, address middleware) internal {
        SymbioticHelper.SymbioticDeployment memory deployment =
            symbioticHelper.getSymbioticDeployment();
        vm.startPrank(user);

        NetworkRegistry(deployment.networkRegistry).registerNetwork();
        NetworkMiddlewareService(deployment.networkMiddlewareService).setMiddleware(middleware);
        vm.stopPrank();
    }

    function randomTransition() internal {
        randomTransition(2 ** nTransitions - 1);
    }

    function randomTransition(uint256 transitoinSubset) internal {
        require((transitoinSubset & (2 ** nTransitions - 1)) > 0);

        uint256 transitionIdx = _randInt(0, nTransitions - 1);
        while (((transitoinSubset >> transitionIdx) & 1) != 1) {
            transitionIdx = _randInt(0, nTransitions - 1);
        }
        transitionByIndex(transitionIdx);
    }

    function transitionByIndex(uint256 transitionIdx) internal {
        require(transitionIdx < nTransitions);
        transitions[transitionIdx]();
        validatateInvariants();
    }

    function transitionEpochSkip() internal {
        skip(epochDuration);
    }

    function finilizeTest() internal {
        for (uint256 i = 0; i < depositors.length; i++) {
            address user = depositors[i];
            uint256 amount = mellowSymbioticVault.maxWithdraw(user);
            vm.prank(user);
            mellowSymbioticVault.withdraw(amount, user, user);
        }
        skip(epochDuration * 2);
        for (uint256 i = 0; i < depositors.length; i++) {
            address user = depositors[i];
            vm.prank(user);
            claimedAmounts[i] += mellowSymbioticVault.claim(user, user, type(uint256).max);
        }
    }

    function validatateInvariants() internal {
        validateLpPrice();

        for (uint256 i = 0; i < depositors.length; i++) {
            assertLe(depositedAmounts[i], limit);
            assertGe(depositedAmounts[i], 0);
        }
    }

    function validateLpPrice() internal {
        // uint256 assets = mellowSymbioticVault.totalAssets();
        // uint256 supply = mellowSymbioticVault.totalSupply();
        // uint256 totalAvailable = totalDepositedAmount - totalSlashedAmount;
        // // lpPrice = assets / supply ~= totalAvailable / totalDepositedAmount

        // emit LpValidation(assets, supply, totalAvailable, totalDepositedAmount);
        // uint256 lpPrice = Math.mulDiv(assets, 1 ether, Math.max(1, supply));
        // uint256 expected = Math.mulDiv(totalAvailable, 1 ether, Math.max(1, totalDepositedAmount));

        // if (totalSlashedAmount == 0) {
        //     assertApproxEqAbs(lpPrice, expected, 1 gwei, "validateLpPrice: lpPrice != expected");
        // } else {
        //     assertLe(lpPrice, 1 ether, "validateLpPrice: lpPrice > 1 ether");
        // }
    }

    function finalValidation() internal view {
        uint256 cumulativeDepositedAmounts = 0;
        uint256 cumulativeWithdrawnAmounts = 0;
        for (uint256 i = 0; i < depositors.length; i++) {
            cumulativeDepositedAmounts += depositedAmounts[i];
            cumulativeWithdrawnAmounts += claimedAmounts[i];
        }

        assertApproxEqAbs(
            cumulativeDepositedAmounts,
            cumulativeWithdrawnAmounts + cumulativeSlashedAmounts,
            1 gwei,
            "cumulativeDepositedAmounts != cumulativeWithdrawnAmounts + cumulativeSlashedAmounts"
        );

        // for (uint256 i = 0; i < depositors.length; i++) {
        //     assertLe(depositedAmounts[i], limit);
        //     assertGe(depositedAmounts[i] - finalWithdrawnAmounts[i], 0);
        //     assertApproxEqAbs(
        //         depositedAmounts[i] - slashedAmounts[i], finalWithdrawnAmounts[i], 1 wei
        //     );
        // }
    }

    function _random() internal returns (uint256) {
        seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, seed)));
        return seed;
    }

    function _randInt(uint256 maxValue) internal returns (uint256) {
        return _random() % (maxValue + 1);
    }

    function _randInt(uint256 minValue, uint256 maxValue) internal returns (uint256) {
        return (_random() % (maxValue - minValue + 1)) + minValue;
    }

    function random_float_x96(uint256 minValue, uint256 maxValue) internal returns (uint256) {
        return _randInt(minValue * Q96, maxValue * Q96);
    }

    function random_bool() internal returns (bool) {
        return _random() & 1 == 1;
    }

    function random_address() internal returns (address) {
        return address(uint160(_random()));
    }

    function calc_random_amount_d18() internal returns (uint256 result) {
        uint256 result_x96 = random_float_x96(D18, 10 * D18);
        if (random_bool()) {
            uint256 b_x96 = random_float_x96(1, 1e6);
            result = Math.mulDiv(result_x96, b_x96, Q96) / Q96;
            assertLe(1 ether, result, "amount overflow");
        } else {
            uint256 b_x96 = random_float_x96(1e1, 1e10);
            result = Math.mulDiv(result_x96, Q96, b_x96) / Q96;
            assertGe(1 ether, result, "amount underflow");
        }
    }

    function _indexOf(address user) internal view returns (uint256) {
        for (uint256 i = 0; i < depositors.length; i++) {
            if (depositors[i] == user) {
                return i;
            }
        }
        return type(uint256).max;
    }

    event Log(string message);
    event LpValidation(
        uint256 assets, uint256 supply, uint256 avaiable, uint256 totalDepositedAmount
    );
}
