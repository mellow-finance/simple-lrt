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

    uint256 private constant ITER = 50;

    uint256 private seed = 42;

    address immutable admin = makeAddr("admin");
    address immutable vaultOwner = makeAddr("vaultOwner");
    address immutable vaultAdmin = makeAddr("vaultAdmin");
    address immutable proxyAdmin = makeAddr("proxyAdmin");
    address immutable mellowVaultAdmin = makeAddr("mellowVaultAdmin");
    address immutable burner = makeAddr("burner");

    address bob = makeAddr("bob");

    uint48 epochDuration = 3600;

    MockRewardToken rewardToken =
        new MockRewardToken("MockRewardTokenName", "MockRewardTokenSymbol", 1e6 ether);

    ISymbioticVault symbioticVault;
    MellowSymbioticVault mellowSymbioticVault;

    uint256 limit;
    address[] depositors;
    uint256[] depositedAmounts;
    uint256[] slashedAmounts;
    uint256[] finalWithdrawnAmounts;

    uint256 totalSlashedAmount = 0;
    uint256 totalDepositedAmount = 0;
    uint256 totalDistributedReward = 0;
    uint256 totalFinalWithdrawnAmount = 0;

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
        transitionPushIntoSymbiotic,
        transitionRandomSlashing,
        transitionRandomFarm
    ];

    uint256 nTransitions = transitions.length;

    MockDefaultStakerRewards defaultStakerRewards;

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

    function testSolvencyAllTransitions() external {
        deploy(1e8 ether, 1e16 ether);

        addRandomUser();

        for (uint256 i = 0; i < ITER; i++) {
            randomTransition();
        }

        finilizeTest();
        finalValidation();
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
        finalWithdrawnAmounts.push(0);
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
                vm.expectRevert("ERC4626 error");
            }
            depositWrapper.deposit{value: s.amount}(
                s.depositToken, s.amount, address(mellowSymbioticVault), s.user, referral
            );
        } else {
            if (s.depositToken != HOLESKY_STETH) {
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
            return;
        }

        uint256 vaultValueAfter = mellowSymbioticVault.totalAssets();
        uint256 vaultSupplyAfter = mellowSymbioticVault.totalSupply();

        console2.log(
            "Deposits:",
            s.amount,
            vaultSupplyAfter - vaultSupplyBefore,
            vaultValueAfter - vaultValueBefore
        );

        assertEq(vaultValueAfter, expectedVaultValueAfter, "vaultValueAfter");
        // assertApproxEqAbs(vaultSupplyAfter, expectedTotalSupplyAfter, 1 gwei, "vaultSupplyAfter");

        depositedAmounts[_indexOf(s.user)] += s.expectedVaultVaultIncrement;
        totalDepositedAmount += s.expectedVaultVaultIncrement;

        vm.stopPrank();
    }

    function transitionRandomWithdrawal() internal {
        address user = depositors[_randInt(0, depositors.length - 1)];
        uint256 amount = calc_random_amount_d18();
        vm.startPrank(user);
        IERC20(HOLESKY_WSTETH).safeIncreaseAllowance(address(mellowSymbioticVault), amount);
        uint256 availableAmount = depositedAmounts[_indexOf(user)] - slashedAmounts[_indexOf(user)];
        if (amount > availableAmount) {
            vm.expectRevert();
            mellowSymbioticVault.withdraw(amount, user, user);
        } else {
            mellowSymbioticVault.withdraw(amount, user, user);
            depositedAmounts[_indexOf(user)] -= amount;
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
            assertEq(balanceAfter - balanceBefore, expectedClaimedAmount, "claimableAmounts");
            assertEq(returnedValue, expectedClaimedAmount, "returnedValue");

            vm.stopPrank();
        } else if (depositors.length != claimableAccounts && random_bool()) {
            // empty claim for depositor

            address user;
            if (random_bool()) {
                uint256 offset = _randInt(depositors.length - claimableAccounts);
                uint256 index;
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
            assertEq(balanceAfter - balanceBefore, expectedClaimedAmount, "claimableAmounts");
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
        emit Log("transitionPushIntoSymbiotic");

        address user = depositors[_randInt(0, depositors.length - 1)];
        vm.startPrank(user);
        mellowSymbioticVault.pushIntoSymbiotic();
        vm.stopPrank();
    }

    function transitionRandomSlashing() internal {
        emit Log("transitionRandomSlashing");
    
        uint256 totalStakedAmount = symbioticVault.totalStake();
        // TODO: WIP
        uint256 slashingAmount = _randInt(totalStakedAmount);
        uint256 mellowStakedAmount = symbioticVault.activeBalanceOf(address(mellowSymbioticVault));

        

        vm.prank(symbioticVault.slasher());
        symbioticVault.onSlash(slashingAmount, uint48(block.timestamp));

        totalSlashedAmount += slashingAmount;
    }

    function transitionRandomFarm() internal {
        address network = bob;
        uint256 distributeAmount = _randInt(1, 1e18);

        totalDistributedReward += distributeAmount;

        vm.startPrank(network);
        defaultStakerRewards.distributeRewards(
            network, address(rewardToken), distributeAmount, abi.encode(block.timestamp, 0, "", "")
        );
        vm.stopPrank();
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

        address network = bob;
        _registerNetwork(network, bob);

        uint256 amount = 100000 * 1e18;
        rewardToken.transfer(bob, 100000 ether);
        vm.startPrank(bob);
        rewardToken.approve(address(defaultStakerRewards), type(uint256).max);

        IERC20(rewardToken).safeIncreaseAllowance(address(bob), amount);
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

    function finilizeTest() internal {
        skip(epochDuration * 2);
        for (uint256 i = 0; i < depositors.length; i++) {
            address user;
            user = depositors[i];
            vm.startPrank(user);
            uint256 amount = mellowSymbioticVault.maxWithdraw(user);
            mellowSymbioticVault.withdraw(amount, user, user);
            finalWithdrawnAmounts[i] += amount;
            totalFinalWithdrawnAmount += amount;
            vm.stopPrank();
        }
        skip(epochDuration * 2);
        for (uint256 i = 0; i < depositors.length; i++) {
            address user;
            user = depositors[i];
            vm.startPrank(user);
            mellowSymbioticVault.claim(user, user, type(uint256).max);
            vm.stopPrank();
        }
        skip(epochDuration * 2);
    }

    function validatateInvariants() internal {
        validateLpPrice();

        for (uint256 i = 0; i < depositors.length; i++) {
            assertLe(depositedAmounts[i], limit);
            assertGe(depositedAmounts[i], 0);
        }
    }

    function validateLpPrice() internal {
        uint256 assets = mellowSymbioticVault.totalAssets();
        uint256 supply = mellowSymbioticVault.totalSupply();
        uint256 totalAvailable = totalDepositedAmount - totalSlashedAmount;
        // lpPrice = assets / supply ~= totalAvailable / totalDepositedAmount

        emit LpValidation(assets, supply, totalAvailable, totalDepositedAmount);
        uint256 lpPrice = Math.mulDiv(assets, 1 ether, Math.max(1, supply));
        uint256 expected = Math.mulDiv(totalAvailable, 1 ether, Math.max(1, totalDepositedAmount));

        if (totalSlashedAmount == 0) {
            assertApproxEqAbs(lpPrice, expected, 1 gwei);
        } else {
            assertLe(lpPrice, 1 ether);
        }
    }

    function finalValidation() internal view {
        assertApproxEqAbs(
            totalDepositedAmount - totalSlashedAmount, totalFinalWithdrawnAmount, 1 gwei
        );

        for (uint256 i = 0; i < depositors.length; i++) {
            assertLe(depositedAmounts[i], limit);
            assertGe(depositedAmounts[i] - finalWithdrawnAmounts[i], 0);
            assertApproxEqAbs(
                depositedAmounts[i] - slashedAmounts[i], finalWithdrawnAmounts[i], 1 wei
            );
        }
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
