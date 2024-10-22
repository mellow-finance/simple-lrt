// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

import {
    FactoryDeploy,
    ISymbioticVault,
    MellowSymbioticVault
} from "../../scripts/mainnet/FactoryDeploy.sol";
import {VaultControl} from "../../src/VaultControl.sol";
import {ISTETH} from "../../src/interfaces/tokens/ISTETH.sol";
import {IWSTETH} from "../../src/interfaces/tokens/IWSTETH.sol";
import {IMellowSymbioticVault} from "../../src/interfaces/vaults/IMellowSymbioticVault.sol";
import {IMellowSymbioticVaultFactory} from
    "../../src/interfaces/vaults/IMellowSymbioticVaultFactory.sol";
import {IMellowSymbioticVaultStorage} from
    "../../src/interfaces/vaults/IMellowSymbioticVaultStorage.sol";
import {IVaultControl} from "../../src/interfaces/vaults/IVaultControl.sol";

import {RandomLib} from "../RandomLib.sol";
import {MockRewardToken} from "../mocks/MockRewardToken.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {INetworkRegistry} from "@symbiotic/core/interfaces/INetworkRegistry.sol";

import {INetworkMiddlewareService} from
    "@symbiotic/core/interfaces/service/INetworkMiddlewareService.sol";
import {DefaultStakerRewards} from
    "@symbiotic/rewards/contracts/defaultStakerRewards/DefaultStakerRewards.sol";
import {IDefaultStakerRewards} from
    "@symbiotic/rewards/interfaces/defaultStakerRewards/IDefaultStakerRewards.sol";
import {IStakerRewards} from "@symbiotic/rewards/interfaces/stakerRewards/IStakerRewards.sol";

contract SolvencyTest is BaseTest {
    using SafeERC20 for IERC20;
    using RandomLib for RandomLib.Storage;

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

    event RandomTransition(uint256 transitionIdx);

    uint256 constant ITERATIONS = 35;
    uint256 constant MAX_ALLOWED_ERROR = ITERATIONS;
    uint256 constant MAX_MEANINGFUL_LIMIT = 1e9 ether;

    RandomLib.Storage internal rnd = RandomLib.Storage(42);
    address immutable admin = makeAddr("admin");
    address immutable vaultOwner = makeAddr("vaultOwner");
    address immutable vaultAdmin = makeAddr("vaultAdmin");
    address immutable proxyAdmin = makeAddr("proxyAdmin");
    address immutable mellowVaultAdmin = makeAddr("mellowVaultAdmin");
    address immutable burner = makeAddr("burner");
    address immutable network = makeAddr("network");
    address immutable distributionFarm = makeAddr("distributionFarm");
    address immutable curatorTreasury = makeAddr("curatorTreasury");
    uint48 immutable epochDuration = 3600;

    MockRewardToken internal rewardToken;
    ISymbioticVault internal symbioticVault;
    MellowSymbioticVault internal mellowSymbioticVault;
    EthWrapper internal depositWrapper;
    IDefaultStakerRewards internal defaultStakerRewards;
    address[] internal depositors;
    uint256[] internal depositedAmounts;
    uint256[] internal claimedAmounts;
    uint256[] internal slashedAmounts;
    uint256[] internal withdrawnAmounts;
    address[] internal symbioticExternalDepositors;
    uint256 internal totalSlashedAmountVault;
    uint256 internal totalSlashedAmountQueue;

    uint256 internal maximalLimit;

    function()[] internal transitions = [
        transitionRandomDeposit,
        transitionRandomWithdrawal,
        transitionRandomLimitSet,
        transitionRandomSymbioticLimitSet,
        transitionRandomDefaultCollateralLimitIncrese,
        transitionRandomClaim,
        transitionRandomSlashing,
        transitionRandomRewardsDistribution,
        transitionPushIntoSymbiotic,
        transitionEpochSkip,
        transitionRandomSkip,
        transitionRandomSymbioticExternalDeposit,
        transitionRandomSymbioticExternalWithdrawal
    ];

    // View helper functions:

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

    function pendingWithdrawalsOf(SymbioticWithdrawalQueue queue, address user, uint256 epoch)
        internal
        view
        returns (uint256 pendingAssets)
    {
        (
            uint256 sharesToClaimPrev,
            uint256 sharesToClaim,
            /*uint256 claimableAssets*/
            ,
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

    // Helper mutable functions:

    function createDefaultStakerRewards() public returns (IDefaultStakerRewards) {
        Constants.SymbioticDeployment memory deployment = symbioticHelper.getSymbioticDeployment();
        DefaultStakerRewards defaultStakerRewards_ =
            new DefaultStakerRewards(deployment.vaultFactory, deployment.networkMiddlewareService);
        IDefaultStakerRewards.InitParams memory params = IDefaultStakerRewards.InitParams({
            vault: address(symbioticVault),
            adminFee: 0,
            defaultAdminRoleHolder: vaultAdmin,
            adminFeeClaimRoleHolder: vaultAdmin,
            adminFeeSetRoleHolder: vaultAdmin
        });

        bytes32 initializerSlot = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;
        vm.store(address(defaultStakerRewards_), initializerSlot, bytes32(0));
        defaultStakerRewards_.initialize(params);

        vm.startPrank(network);
        INetworkRegistry(deployment.networkRegistry).registerNetwork();
        INetworkMiddlewareService(deployment.networkMiddlewareService).setMiddleware(network);
        vm.stopPrank();

        return defaultStakerRewards_;
    }

    // Setup functions:

    function setUp() external {
        // logic below is used to prevent STAKE_LIMIT error in stETH contract
        bytes32 slot_ = 0xa3678de4a579be090bed1177e0a24f77cc29d181ac22fd7688aca344d8938015;
        bytes32 value = vm.load(Constants.STETH(), slot_);
        bytes32 new_value = bytes32(uint256(value) & type(uint160).max); // nullify maxStakeLimit
        vm.store(Constants.STETH(), slot_, new_value);
    }

    function deploy(uint256 _seed, uint256 _limit, uint256 _symbioticLimit) public {
        delete rewardToken;
        delete symbioticVault;
        delete mellowSymbioticVault;
        delete depositWrapper;
        delete defaultStakerRewards;
        delete depositors;
        delete depositedAmounts;
        delete claimedAmounts;
        delete slashedAmounts;
        delete totalSlashedAmountVault;
        delete totalSlashedAmountQueue;
        delete maximalLimit;

        rnd.seed = _seed;

        rewardToken = new MockRewardToken("MockRewardTokenName", "MockRewardTokenSymbol", 1e6 ether);
        depositWrapper = new EthWrapper(Constants.WETH(), Constants.WSTETH(), Constants.STETH());

        _symbioticLimit = Math.min(_symbioticLimit, MAX_MEANINGFUL_LIMIT);
        symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParamsExtended({
                    vaultOwner: vaultOwner,
                    vaultAdmin: vaultAdmin,
                    burner: burner,
                    epochDuration: epochDuration,
                    asset: Constants.WSTETH(),
                    isDepositLimit: false,
                    depositLimit: _symbioticLimit
                })
            )
        );

        _limit = Math.min(_limit, MAX_MEANINGFUL_LIMIT);
        _limit = Math.max(_limit, 1);
        IMellowSymbioticVaultFactory.InitParams memory initParams = IMellowSymbioticVaultFactory
            .InitParams({
            proxyAdmin: proxyAdmin,
            limit: _limit,
            symbioticCollateral: address(Constants.WSTETH_SYMBIOTIC_COLLATERAL()),
            symbioticVault: address(symbioticVault),
            admin: admin,
            depositPause: false,
            withdrawalPause: false,
            depositWhitelist: false,
            name: "MellowSymbioticVault",
            symbol: "MSV"
        });
        maximalLimit = _limit;

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

        (
            IMellowSymbioticVault iMellowSymbioticVault, /* FactoryDeploy.FactoryDeployParams memory __ */
        ) = FactoryDeploy.deploy(factoryDeployParams);
        mellowSymbioticVault = MellowSymbioticVault(address(iMellowSymbioticVault));

        defaultStakerRewards = createDefaultStakerRewards();

        vm.startPrank(admin);
        mellowSymbioticVault.grantRole(SET_FARM_ROLE, admin);

        IMellowSymbioticVaultStorage.FarmData memory farmData = IMellowSymbioticVaultStorage
            .FarmData({
            rewardToken: address(rewardToken),
            symbioticFarm: address(defaultStakerRewards),
            distributionFarm: distributionFarm,
            curatorTreasury: curatorTreasury,
            curatorFeeD6: 100000 // 10%
        });
        mellowSymbioticVault.setFarm(1, farmData);

        vm.stopPrank();
    }

    // Test functions:

    function runSolvencyAllTransitionsForSeed(uint256 seed_) internal {
        deploy(seed_, 1e8 ether, 1e16 ether);

        for (uint256 i = 0; i < ITERATIONS; i++) {
            randomTransition();
        }

        finalizeTest();
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

    function testFuzz_TransitionSubset(
        uint256 _seed,
        uint256 _limit,
        uint256 _symbioticLimit,
        uint256 transitionSubset
    ) external {
        deploy(_seed, _limit, _symbioticLimit);
        uint256 fullMask = (1 << transitions.length) - 1;
        if (transitionSubset & fullMask == 0) {
            transitionSubset = rnd.randInt(1, fullMask);
        }
        transitionSubset &= fullMask;

        for (uint256 i = 0; i < ITERATIONS; i++) {
            randomTransition(transitionSubset);
        }

        finalizeTest();
        finalValidation();
    }

    function testFuzz_TrasitionList(
        uint256 _seed,
        uint256 _limit,
        uint256 _symbioticLimit,
        uint16 _transitions
    ) external {
        deploy(_seed, _limit, _symbioticLimit);
        _transitions = uint16(Math.min(uint256(_transitions), 1000));

        for (uint256 i = 0; i < _transitions; i++) {
            randomTransition();
        }

        finalizeTest();
        finalValidation();
    }

    function addRandomUser() internal returns (address) {
        address user = rnd.randAddress();
        depositors.push(user);
        depositedAmounts.push(0);
        slashedAmounts.push(0);
        claimedAmounts.push(0);
        withdrawnAmounts.push(0);
        return user;
    }

    struct StackTransitionRandomDeposit {
        address user;
        uint256 amount;
        uint256 expectedValueIncrement;
        uint256 expectedSupplyIncrement;
        address depositToken;
        bool withDepositWrapper;
        bool withPlainEth;
    }

    function transitionRandomDeposit() internal {
        StackTransitionRandomDeposit memory s;

        uint256 userIndex;
        if (rnd.randBool() || depositors.length == 0) {
            addRandomUser();
            userIndex = depositors.length - 1;
        } else {
            userIndex = rnd.randInt(0, depositors.length - 1);
        }

        s.user = depositors[userIndex];
        s.amount = rnd.randAmountD18();

        s.withDepositWrapper = rnd.randBool();
        s.withPlainEth = false;
        if (s.withDepositWrapper) {
            s.depositToken = [
                depositWrapper.ETH(),
                depositWrapper.wstETH(),
                depositWrapper.stETH(),
                depositWrapper.WETH()
            ][rnd.randInt(3)];
            if (s.depositToken == depositWrapper.ETH()) {
                s.withPlainEth = true;
            }
        } else {
            s.depositToken = Constants.WSTETH();
        }

        s.expectedValueIncrement = s.amount;
        if (s.depositToken != Constants.WSTETH()) {
            // eth == weth == steth = price * wsteth
            s.expectedValueIncrement = IWSTETH(Constants.WSTETH()).getWstETHByStETH(s.amount);
        }

        SystemSnapshot memory before_ = getSnapshot();

        uint256 expectedVaultValueAfter = before_.mellowTotalAssets + s.expectedValueIncrement;
        s.expectedSupplyIncrement = Math.mulDiv(
            s.expectedValueIncrement,
            before_.mellowTotalSupply + 1,
            before_.mellowTotalAssets + 1 // OZ ERC4626 logic
        );
        uint256 expectedTotalSupplyAfter = before_.mellowTotalSupply + s.expectedSupplyIncrement;

        assertEq(
            mellowSymbioticVault.previewDeposit(s.expectedValueIncrement),
            s.expectedSupplyIncrement,
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
            if (s.depositToken != Constants.STETH()) {
                if (s.depositToken == Constants.WETH()) {
                    deal(Constants.WETH(), s.amount); // to avoid OOF
                }
                deal(s.depositToken, s.user, s.amount);
            } else {
                deal(s.user, s.amount);
                ISTETH(Constants.STETH()).submit{value: s.amount}(address(0));
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

        if (!isLimitOverflowExpected) {
            SystemSnapshot memory after_ = getSnapshot();

            assertApproxEqAbs(
                after_.mellowTotalAssets,
                expectedVaultValueAfter,
                1,
                "transitionRandomDeposit: actual totalAssets != exepcted totalAssets"
            );
            assertApproxEqAbs(
                after_.mellowTotalSupply,
                expectedTotalSupplyAfter,
                1,
                "transitionRandomDeposit: actual totalSupply != expected totalSupply"
            );
            depositedAmounts[userIndex] += s.expectedValueIncrement;
        }

        vm.stopPrank();
    }

    struct TransitionRandomWithdrawalStack {
        uint256 userIndex;
        address user;
        uint256 expectedAssetsDecrement;
        uint256 expectedSupplyDecrement;
        bool isRevertExpected;
    }

    function transitionRandomWithdrawal() internal {
        if (depositors.length == 0) {
            // nothing to withdraw
            return;
        }
        TransitionRandomWithdrawalStack memory s;

        s.userIndex = rnd.randInt(0, depositors.length - 1);
        s.user = depositors[s.userIndex];
        uint256 withdrawableAmount;
        SystemSnapshot memory before_ = getSnapshot();

        {
            uint256 pendingAssetsOf_ = mellowSymbioticVault.pendingAssetsOf(s.user);
            uint256 claimableAssetsOf_ = mellowSymbioticVault.claimableAssetsOf(s.user);

            uint256 availableAmount = depositedAmounts[s.userIndex];
            uint256 currentAmounts = slashedAmounts[s.userIndex] + pendingAssetsOf_
                + claimableAssetsOf_ + claimedAmounts[s.userIndex];

            assertGe(
                availableAmount + MAX_ALLOWED_ERROR,
                currentAmounts,
                "transitionRandomWithdrawal: availableAmount"
            );
            availableAmount -= Math.min(availableAmount, currentAmounts);

            withdrawableAmount = mellowSymbioticVault.maxWithdraw(s.user);
            assertApproxEqAbs(
                withdrawableAmount,
                availableAmount,
                MAX_ALLOWED_ERROR,
                "transitionRandomWithdrawal: withdrawableAmount != availableAmount"
            );
        }

        uint256 amount;
        s.isRevertExpected = rnd.randBool();
        if (s.isRevertExpected) {
            amount = rnd.randInt(withdrawableAmount + 1, (before_.mellowTotalAssets + 1) * 2);
        } else {
            amount = rnd.randInt(withdrawableAmount);
        }

        if (!s.isRevertExpected) {
            s.expectedAssetsDecrement = amount;
            s.expectedSupplyDecrement = Math.mulDiv(
                amount,
                before_.mellowTotalSupply + 1,
                before_.mellowTotalAssets + 1,
                Math.Rounding.Ceil
            );
        }

        uint256 userBalanceBefore = IERC20(Constants.WSTETH()).balanceOf(s.user);

        vm.startPrank(s.user);
        if (s.isRevertExpected) {
            vm.expectRevert();
        }

        uint256 withdrawnShares = mellowSymbioticVault.withdraw(amount, s.user, s.user);
        uint256 userBalanceAfter = IERC20(Constants.WSTETH()).balanceOf(s.user);

        SystemSnapshot memory after_ = getSnapshot();

        assertEq(
            withdrawnShares,
            s.expectedSupplyDecrement,
            "transitionRandomWithdrawal: withdrawnShares"
        );

        assertApproxEqAbs(
            before_.mellowTotalAssets,
            after_.mellowTotalAssets + s.expectedAssetsDecrement,
            2 wei,
            "transitionRandomWithdrawal: totalAssets"
        );

        assertApproxEqAbs(
            before_.mellowTotalSupply,
            after_.mellowTotalSupply + s.expectedSupplyDecrement,
            2 wei,
            "transitionRandomWithdrawal: totalSupply"
        );

        assertApproxEqAbs(
            before_.positions[s.userIndex].assets,
            after_.positions[s.userIndex].assets + s.expectedAssetsDecrement,
            2 wei,
            "transitionRandomWithdrawal: userAssets"
        );

        assertApproxEqAbs(
            before_.positions[s.userIndex].shares,
            after_.positions[s.userIndex].shares + s.expectedSupplyDecrement,
            2 wei,
            "transitionRandomWithdrawal: userShares"
        );

        assertApproxEqAbs(
            userBalanceBefore + before_.positions[s.userIndex].pendingNext
                + s.expectedAssetsDecrement,
            userBalanceAfter + after_.positions[s.userIndex].pendingNext,
            2 wei,
            "transitionRandomWithdrawal: userBalance"
        );

        // we can assume that all instantly withdrawn assets are the same as queued && claimed instantly assets
        claimedAmounts[s.userIndex] += userBalanceAfter - userBalanceBefore;
        withdrawnAmounts[s.userIndex] += s.expectedAssetsDecrement;

        vm.stopPrank();
    }

    function transitionRandomClaim() internal {
        SystemSnapshot memory before_ = getSnapshot();

        uint256 claimableAddresses = 0;
        for (uint256 i = 0; i < before_.positions.length; i++) {
            if (before_.positions[i].claimable > 0) {
                claimableAddresses++;
            }
        }

        // If we have any addresses with claimable assets, we will claim from one of them with a 50% chance
        if (claimableAddresses != 0 && rnd.randBool()) {
            // successfull claim
            uint256 offset = rnd.randInt(claimableAddresses - 1);
            uint256 index;
            for (uint256 i = 0; i < before_.positions.length; i++) {
                if (before_.positions[i].claimable > 0) {
                    if (offset == 0) {
                        index = i;
                        break;
                    }
                    offset--;
                }
            }

            address user = depositors[index];
            uint256 userBalanceBefore = IERC20(Constants.WSTETH()).balanceOf(user);

            uint256 claimingAmount = rnd.randInt(before_.positions[index].claimable * 2); // probably more than claimable
            uint256 expectedClaimedAmount =
                Math.min(claimingAmount, before_.positions[index].claimable);

            vm.prank(user);
            uint256 claimedAssets = mellowSymbioticVault.claim(user, user, claimingAmount);

            uint256 userBalanceAfter = IERC20(Constants.WSTETH()).balanceOf(user);
            assertEq(
                userBalanceAfter - userBalanceBefore,
                claimedAssets,
                "transitionRandomClaim: claimedAssets"
            );
            assertEq(
                claimedAssets, expectedClaimedAmount, "transitionRandomClaim: expectedClaimedAmount"
            );

            vm.stopPrank();

            claimedAmounts[index] += claimedAssets;
            SystemSnapshot memory after_ = getSnapshot();

            assertEq(
                before_.mellowTotalAssets,
                after_.mellowTotalAssets,
                "transitionRandomClaim: totalAssets"
            );

            assertEq(
                before_.mellowTotalSupply,
                after_.mellowTotalSupply,
                "transitionRandomClaim: totalSupply"
            );

            assertEq(
                before_.positions[index].claimable,
                after_.positions[index].claimable + claimedAssets,
                "transitionRandomClaim: totalAssets"
            );

            assertEq(
                before_.mellowTotalSupply,
                after_.mellowTotalSupply,
                "transitionRandomClaim: totalSupply"
            );
        } else {
            address user;
            if (rnd.randBool() && depositors.length > claimableAddresses) {
                // empty claim for depositor
                uint256 offset = rnd.randInt(depositors.length - claimableAddresses - 1);
                uint256 index = type(uint256).max;
                for (uint256 i = 0; i < depositedAmounts.length; i++) {
                    if (before_.positions[i].claimable == 0) {
                        if (offset == 0) {
                            index = i;
                            break;
                        }
                        offset--;
                    }
                }
                user = depositors[index];
            } else {
                // empty claim for random user
                user = rnd.randAddress();
            }

            uint256 claimingAmount = rnd.randInt(mellowSymbioticVault.totalAssets() * 2);
            uint256 claimableAmount = 0;
            uint256 balanceBefore = IERC20(Constants.WSTETH()).balanceOf(user);

            uint256 expectedClaimedAmount = Math.min(claimingAmount, claimableAmount);

            vm.prank(user);
            uint256 returnedValue = mellowSymbioticVault.claim(user, user, claimingAmount);

            uint256 balanceAfter = IERC20(Constants.WSTETH()).balanceOf(user);
            assertEq(
                balanceAfter - balanceBefore,
                expectedClaimedAmount,
                "claimableAmounts (random user)"
            );
            assertEq(returnedValue, expectedClaimedAmount, "returnedValue");

            SystemSnapshot memory after_ = getSnapshot();

            assertEq(
                before_.mellowTotalAssets,
                after_.mellowTotalAssets,
                "transitionRandomClaim: totalAssets"
            );

            assertEq(
                before_.mellowTotalSupply,
                after_.mellowTotalSupply,
                "transitionRandomClaim: totalSupply"
            );

            vm.stopPrank();
        }
    }

    function transitionRandomLimitSet() internal {
        uint256 newLimit;
        uint256 limit = mellowSymbioticVault.limit();
        if (rnd.randBool()) {
            // increase limit
            uint256 increment = rnd.randInt(1, Math.max(limit * 2, 1));
            newLimit = Math.min(limit + increment, MAX_MEANINGFUL_LIMIT);
        } else {
            // decrease limit
            uint256 decrement = rnd.randInt(1, limit);
            newLimit = Math.max(limit - decrement, 10 wei);
        }

        vm.startPrank(admin);
        if (!mellowSymbioticVault.hasRole(SET_LIMIT_ROLE, admin)) {
            mellowSymbioticVault.grantRole(SET_LIMIT_ROLE, admin);
        }
        mellowSymbioticVault.setLimit(newLimit);
        maximalLimit = Math.max(maximalLimit, newLimit);
        vm.stopPrank();
    }

    function transitionRandomSymbioticLimitSet() internal {
        if (symbioticVault.isDepositLimit()) {
            if (rnd.randBool()) {
                uint256 newLimit;
                uint256 limit = symbioticVault.depositLimit();
                if (rnd.randBool() || limit == 0) {
                    // increase limit
                    uint256 maxValue =
                        limit >= MAX_MEANINGFUL_LIMIT ? MAX_MEANINGFUL_LIMIT : (limit + 1) * 2;
                    uint256 increment = rnd.randInt(1, maxValue);
                    newLimit = Math.min(limit + increment, MAX_MEANINGFUL_LIMIT);
                } else {
                    // decrease limit
                    uint256 decrement = rnd.randInt(1, limit);
                    newLimit = Math.max(limit - decrement, 10 wei);
                }

                newLimit = Math.min(newLimit, MAX_MEANINGFUL_LIMIT);

                if (limit == newLimit) {
                    newLimit--;
                }

                vm.prank(vaultAdmin);
                symbioticVault.setDepositLimit(newLimit);
            } else {
                vm.prank(vaultAdmin);
                symbioticVault.setIsDepositLimit(false);
            }
        } else {
            vm.prank(vaultAdmin);
            symbioticVault.setIsDepositLimit(true);
        }
    }

    function transitionRandomDefaultCollateralLimitIncrese() internal {
        IDefaultCollateral collateral =
            IDefaultCollateral(mellowSymbioticVault.symbioticCollateral());

        uint256 limit = collateral.limit();

        uint256 increment = rnd.randAmountD18();
        increment = Math.min(type(uint256).max - limit, increment);
        if (increment == 0) {
            return;
        }

        vm.prank(collateral.limitIncreaser());
        collateral.increaseLimit(increment);
    }

    function transitionPushIntoSymbiotic() internal {
        address caller = rnd.randAddress();
        vm.prank(caller);
        mellowSymbioticVault.pushIntoSymbiotic();
    }

    function transitionRandomSlashing() internal {
        TransitionRandomSlashingStack memory s;
        s.before_ = getSnapshot();

        // scenario for current epoch
        if (rnd.randBool() || symbioticVault.currentEpoch() == 0) {
            s.captureTimestamp = s.before_.timestamp;

            assertEq(
                symbioticVault.epochAt(s.captureTimestamp),
                s.before_.epoch,
                "transitionRandomSlashing (current epoch): epochAt(captureTimestamp) != currentEpoch"
            );

            uint256 symbioticSlashableStake =
                s.before_.symbioticActiveStake + s.before_.symbioticWithdrawalsNext;

            if (symbioticSlashableStake == 0) {
                // nothing to slash -> early exit
                return;
            }

            s.slashingAmount = rnd.randInt(1, symbioticSlashableStake);

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

            assertApproxEqAbs(
                s.before_.mellowWithdrawals,
                s.after_.mellowWithdrawals + s.mellowWithdrawalsSlashed,
                1,
                "transitionRandomSlashing (current epoch): mellowWithdrawals"
            );
            assertApproxEqAbs(
                s.before_.mellowWithdrawalsNext,
                s.after_.mellowWithdrawalsNext + s.mellowWithdrawalsNextSlashed,
                1,
                "transitionRandomSlashing (current epoch): mellowWithdrawalsNext"
            );

            totalSlashedAmountVault += s.mellowActiveStakeSlashed;
            totalSlashedAmountQueue += s.mellowWithdrawalsSlashed + s.mellowWithdrawalsNextSlashed;

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
                        2,
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
                        2,
                        "transitionRandomSlashing (current epoch): staked"
                    );
                    assertApproxEqAbs(
                        s.before_.positions[i].assets,
                        s.after_.positions[i].assets + slashed,
                        2,
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

            uint256 symbioticSlashableStake = s.before_.symbioticActiveStake
                + s.before_.symbioticWithdrawals + s.before_.symbioticWithdrawalsNext;

            if (symbioticSlashableStake == 0) {
                // nothing to slash -> early exit
                return;
            }

            s.slashingAmount = rnd.randInt(1, symbioticSlashableStake);

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

            assertApproxEqAbs(
                s.before_.mellowWithdrawals,
                s.after_.mellowWithdrawals + s.mellowWithdrawalsSlashed,
                2,
                "transitionRandomSlashing (previous epoch): mellowWithdrawals"
            );
            assertApproxEqAbs(
                s.before_.mellowWithdrawalsNext,
                s.after_.mellowWithdrawalsNext + s.mellowWithdrawalsNextSlashed,
                1,
                "transitionRandomSlashing (previous epoch): mellowWithdrawalsNext"
            );

            totalSlashedAmountVault += s.mellowActiveStakeSlashed;
            totalSlashedAmountQueue += s.mellowWithdrawalsSlashed + s.mellowWithdrawalsNextSlashed;

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
                        2,
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
                        2,
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
                        2,
                        "transitionRandomSlashing (previous epoch): staked"
                    );
                    assertApproxEqAbs(
                        s.before_.positions[i].assets,
                        s.after_.positions[i].assets + slashed,
                        2,
                        "transitionRandomSlashing (previous epoch): assets"
                    );
                }
            }
        }
    }

    function transitionRandomRewardsDistribution() internal {
        // function distributes rewards according to staked amounts at the moment dirstributionTimestamp
        uint256 distributeAmount = rnd.randAmountD18();
        uint48 distributionTimestamp = uint48(block.timestamp - rnd.randInt(1, epochDuration * 2));
        uint256 activeShares_ = symbioticVault.activeSharesAt(distributionTimestamp, "");
        uint256 activeStake_ = symbioticVault.activeStakeAt(distributionTimestamp, "");
        if (activeShares_ == 0 || activeStake_ == 0) {
            // nothing to reward
            return;
        }

        uint256 maxAdminFee = 0;
        bytes memory activeSharesHint;
        bytes memory activeStakeHint;
        bytes memory data =
            abi.encode(distributionTimestamp, maxAdminFee, activeSharesHint, activeStakeHint);
        deal(address(rewardToken), network, distributeAmount);

        vm.startPrank(network);
        IERC20(address(rewardToken)).safeIncreaseAllowance(
            address(defaultStakerRewards), distributeAmount
        );
        defaultStakerRewards.distributeRewards(
            network, address(rewardToken), distributeAmount, data
        );
        assertEq(
            rewardToken.balanceOf(network),
            0,
            "transitionRandomRewardsDistribution: rewardToken.balanceOf(network)"
        );
        vm.stopPrank();
    }

    function transitionRandomSymbioticExternalDeposit() internal {
        address asset = Constants.WSTETH();
        address user = rnd.randAddress();
        uint256 amount = rnd.randAmountD18();

        uint256 depositLimit = symbioticVault.depositLimit();
        uint256 totalStake = symbioticVault.totalStake();

        uint256 leftover;
        if (symbioticVault.isDepositLimit()) {
            leftover = depositLimit >= totalStake ? depositLimit - totalStake : 0;
        } else {
            leftover = type(uint256).max - totalStake;
        }

        amount = Math.min(amount, leftover);
        if (amount == 0) {
            // nothing to deposit
            return;
        }

        deal(asset, user, amount);
        vm.startPrank(user);
        IERC20(asset).safeIncreaseAllowance(address(symbioticVault), amount);

        SystemSnapshot memory before_ = getSnapshot();
        symbioticVault.deposit(user, amount);
        SystemSnapshot memory after_ = getSnapshot();

        assertEq(
            before_.symbioticTotalStake + amount,
            after_.symbioticTotalStake,
            "transitionRandomSymbioticExternalDeposit: symbioticTotalStake"
        );

        assertEq(
            before_.symbioticActiveStake + amount,
            after_.symbioticActiveStake,
            "transitionRandomSymbioticExternalDeposit: symbioticActiveStake"
        );

        vm.stopPrank();

        symbioticExternalDepositors.push(user);
    }

    function transitionRandomSymbioticExternalWithdrawal() internal {
        if (symbioticExternalDepositors.length == 0) {
            return;
        }

        address[] memory activeDepositors = new address[](symbioticExternalDepositors.length);
        uint256 index = 0;

        for (uint256 i = 0; i < symbioticExternalDepositors.length; i++) {
            address user = symbioticExternalDepositors[i];
            if (symbioticVault.activeBalanceOf(user) == 0) {
                continue;
            }
            activeDepositors[index++] = user;
        }

        if (index == 0) {
            return;
        }

        address depositor = activeDepositors[rnd.randInt(index - 1)];
        uint256 requestingAmount = rnd.randInt(1, symbioticVault.activeBalanceOf(depositor));

        vm.startPrank(depositor);

        SystemSnapshot memory before_ = getSnapshot();

        (uint256 burnedShares, /* uint256 mintedShares */ ) =
            symbioticVault.withdraw(depositor, requestingAmount);

        SystemSnapshot memory after_ = getSnapshot();

        assertEq(
            before_.symbioticTotalStake,
            after_.symbioticTotalStake,
            "transitionRandomSymbioticExternalWithdrawal: symbioticTotalStake"
        );

        assertEq(
            before_.symbioticActiveStake - requestingAmount,
            after_.symbioticActiveStake,
            "transitionRandomSymbioticExternalWithdrawal: symbioticActiveStake"
        );

        assertEq(
            before_.symbioticActiveShares - burnedShares,
            after_.symbioticActiveShares,
            "transitionRandomSymbioticExternalWithdrawal: symbioticActiveShares"
        );

        assertEq(
            before_.symbioticWithdrawalsNext + requestingAmount,
            after_.symbioticWithdrawalsNext,
            "transitionRandomSymbioticExternalWithdrawal: symbioticWithdrawalsNext"
        );

        vm.stopPrank();
    }

    function randomTransition() internal {
        randomTransition(2 ** transitions.length - 1);
    }

    function randomTransition(uint256 transitoinSubset) internal {
        uint256 n = transitions.length;
        uint256 nonZeroBits = 0;
        for (uint256 i = 0; i < n; i++) {
            if (((transitoinSubset >> i) & 1) == 1) {
                nonZeroBits++;
            }
        }
        uint256 index = rnd.randInt(nonZeroBits - 1);
        for (uint256 i = 0; i < n; i++) {
            if (((transitoinSubset >> i) & 1) == 1) {
                if (index == 0) {
                    transitionByIndex(i);
                    return;
                }
                index--;
            }
        }
        revert("randomTransition: Invalid state");
    }

    function transitionByIndex(uint256 transitionIdx) internal {
        require(transitionIdx < transitions.length, "transitionByIndex: Invalid transitionIdx");
        emit RandomTransition(transitionIdx);
        transitions[transitionIdx]();
        validateInvariants();
    }

    function transitionEpochSkip() internal {
        skip(epochDuration);
    }

    function transitionRandomSkip() internal {
        skip(rnd.randInt(1, epochDuration * 2));
    }

    function finalizeTest() internal {
        for (uint256 i = 0; i < depositors.length; i++) {
            address user = depositors[i];
            uint256 shares = mellowSymbioticVault.balanceOf(user);

            uint256 userBalanceBefore = IERC20(Constants.WSTETH()).balanceOf(user);
            uint256 assets = mellowSymbioticVault.previewRedeem(shares);

            vm.prank(user);
            mellowSymbioticVault.redeem(shares, user, user);

            uint256 userBalanceAfter = IERC20(Constants.WSTETH()).balanceOf(user);
            uint256 instantlyWithdrawnAmounts = userBalanceAfter - userBalanceBefore;
            claimedAmounts[i] += instantlyWithdrawnAmounts;
            withdrawnAmounts[i] += assets;
        }
        skip(epochDuration * 2);
        for (uint256 i = 0; i < depositors.length; i++) {
            address user = depositors[i];
            vm.prank(user);
            uint256 claimed = mellowSymbioticVault.claim(user, user, type(uint256).max);
            claimedAmounts[i] += claimed;
        }

        assertEq(mellowSymbioticVault.totalSupply(), 0, "finalizeTest: totalSupply() != 0");
    }

    function validateInvariants() internal view {
        uint256 totalDeposited = 0;
        uint256 totalWithdrawn = 0;

        for (uint256 i = 0; i < depositors.length; i++) {
            totalDeposited += depositedAmounts[i];
            totalWithdrawn += withdrawnAmounts[i];
        }

        SystemSnapshot memory snapshot = getSnapshot();

        assertApproxEqAbs(
            totalDeposited - totalWithdrawn,
            snapshot.mellowTotalAssets + totalSlashedAmountVault,
            MAX_ALLOWED_ERROR ** 2,
            "validateInvariants: totalDeposited - totalWithdrawn != totalAssets + totalSlashedAmountVault"
        );

        for (uint256 i = 0; i < depositors.length; i++) {
            assertLe(
                depositedAmounts[i],
                maximalLimit,
                "validateInvariants: Deposited more than maximal limit"
            );
            assertGe(depositedAmounts[i], 0, "validateInvariants: Deposited less than 0");

            assertApproxEqAbs(
                depositedAmounts[i],
                claimedAmounts[i] + slashedAmounts[i] + snapshot.positions[i].pending
                    + snapshot.positions[i].claimable + snapshot.positions[i].pendingNext
                    + snapshot.positions[i].assets,
                MAX_ALLOWED_ERROR,
                "validateInvariants: depositedAmounts[i] != claimedAmounts[i] + slashedAmounts[i] + pending + claimable"
            );
        }
    }

    function finalValidation() internal view {
        validateInvariants();
        uint256 totalDepositedAmount = 0;
        uint256 totalClaimedAmount = 0;
        for (uint256 i = 0; i < depositors.length; i++) {
            totalDepositedAmount += depositedAmounts[i];
            totalClaimedAmount += claimedAmounts[i];
        }

        assertApproxEqAbs(
            totalDepositedAmount,
            totalClaimedAmount + totalSlashedAmountVault + totalSlashedAmountQueue,
            MAX_ALLOWED_ERROR ** 2,
            "finalValidation: totalDepositedAmount != totalClaimedAmount + totalSlashedAmount"
        );

        SystemSnapshot memory snapshot = getSnapshot();

        for (uint256 i = 0; i < snapshot.positions.length; i++) {
            assertEq(snapshot.positions[i].pending, 0, "finalValidation: pending != 0");
            assertEq(snapshot.positions[i].pendingNext, 0, "finalValidation: pendingNext != 0");
            assertEq(snapshot.positions[i].claimable, 0, "finalValidation: claimable != 0");
            assertEq(snapshot.positions[i].staked, 0, "finalValidation: staked != 0");
            assertEq(snapshot.positions[i].assets, 0, "finalValidation: assets != 0");
        }
    }
}
