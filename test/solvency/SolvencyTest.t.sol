// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";
import "../../src/interfaces/vaults/IVaultControl.sol";
import "../../src/VaultControl.sol";
import "../../scripts/mainnet/FactoryDeploy.sol";

import {IStakerRewards} from "@symbiotic/rewards/interfaces/stakerRewards/IStakerRewards.sol";
import {IDefaultStakerRewards} from "@symbiotic/rewards/interfaces/defaultStakerRewards/IDefaultStakerRewards.sol";
import {MockDefaultStakerRewards} from "../mocks/MockDefaultStakerRewards.sol";

contract SolvencyTest is BaseTest {
    using SafeERC20 for IERC20;

    uint256 ITER = 20;
    bytes32 private constant SET_LIMIT_ROLE = keccak256("SET_LIMIT_ROLE");

    address admin = makeAddr("admin");

    uint256 private seed = 42; 

    uint256 public constant MAX_ERROR = 10 wei;
    uint256 public constant Q96 = 2 ** 96;
    uint256 public constant D18 = 1e18;

    address wsteth = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;
    address vaultOwner = makeAddr("vaultOwner");
    address vaultAdmin = makeAddr("vaultAdmin");
    address proxyAdmin = makeAddr("proxyAdmin");
    address mellowVaultAdmin = makeAddr("mellowVaultAdmin");
    address burner = makeAddr("burner");
    uint48 epochDuration = 3600;
    address rewardToken1 = makeAddr("rewardToken1");

    uint256 symbioticLimit;
    ISymbioticVault symbioticVault;
    MellowSymbioticVault mellowSymbioticVault;

    uint256 limit;
    address[] public depositors;
    uint256[] public depositedAmounts;
    uint256[] public withdrawnAmounts;

    uint256 nTransitions = 7;

    MockDefaultStakerRewards defaultStakerRewards;

    function testRunSolvency() external {
        deploy(1e8 ether, 1e16 ether);

        addRandomUser();

        for (uint256 i = 0; i < ITER; i++) {
            randomTransition();
        }

        finilizeTest();
        finalValidation();
    }

    function testRandomTransitionSubset() external {
        deploy(1e8 ether, 1e16 ether);

        addRandomUser();
        uint256 transitionSubset = _randInt(1, 2 ** nTransitions - 1);
        for (uint256 i = 0; i < ITER; i++) {
            randomTransition(transitionSubset);
        }

        finilizeTest();
        finalValidation();
    }

    function fuzzyTestTransitonBitmask(uint256 iter, uint256 _limit, uint256 _symbioticLimit, uint256 transitionSubset) external {
        deploy(_limit, _symbioticLimit);

        addRandomUser();
        for (uint256 i = 0; i < iter; i++) {
            randomTransition(transitionSubset);
        }

        finilizeTest();
        finalValidation();
    }

    function fuzzyTestTrasitionList(uint256[] memory transitions, uint256 _limit, uint256 _symbioticLimit) external {
        deploy(_limit, _symbioticLimit);

        addRandomUser();
        for (uint256 i = 0; i < transitions.length; i++) {
            transitionByIndex(transitions[i]);
        }

        finilizeTest();
        finalValidation();
    }

    function deploy(uint256 _limit, uint256 _symbioticLimit) public {
        symbioticLimit = _symbioticLimit;
        symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParamsExtended({
                    vaultOwner: vaultOwner,
                    vaultAdmin: vaultAdmin,
                    burner: burner,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    isDepositLimit: false,
                    depositLimit: symbioticLimit
                })
            )
        );

        limit = _limit;
        IMellowSymbioticVaultFactory.InitParams memory initParams = IMellowSymbioticVaultFactory.InitParams({
            proxyAdmin: proxyAdmin,
            limit: limit,
            symbioticCollateral: address(wstethSymbioticCollateral),
            symbioticVault: address(symbioticVault),
            admin: admin,
            depositPause: false,
            withdrawalPause: false,
            depositWhitelist: false,
            name: "MellowSymbioticVault",
            symbol: "MSV"
        });


        FactoryDeploy.FactoryDeployParams memory factoryDeployParams = FactoryDeploy.FactoryDeployParams({
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

        (IMellowSymbioticVault iMellowSymbioticVault, 
         FactoryDeploy.FactoryDeployParams memory __
        ) = FactoryDeploy.deploy(factoryDeployParams);
        mellowSymbioticVault = MellowSymbioticVault(address(iMellowSymbioticVault));

        defaultStakerRewards = createDefaultStakerRewards();
    }

    function addRandomUser() internal returns (address)  {
        address user = random_address();
        depositors.push(user);
        depositedAmounts.push(0);
        withdrawnAmounts.push(0);
        return user;
    }

    function transitionRandomDeposit() internal {
        address user;
        if (random_bool()) {
            user = addRandomUser();
        } else {
            user = depositors[_randInt(0, depositors.length - 1)];
        }
        uint256 amount = calc_random_amount_d18();
        deal(wsteth, user, amount);
        vm.startPrank(user);
        IERC20(wsteth).safeIncreaseAllowance(
            address(mellowSymbioticVault),
            amount
        );

        if (depositedAmounts[_indexOf(user)] + amount > limit) {
            vm.expectRevert();
            mellowSymbioticVault.deposit(amount, user, address(0));
        } else {
            mellowSymbioticVault.deposit(amount, user, address(0));
            depositedAmounts[_indexOf(user)] += amount;
        }
        vm.stopPrank();
    }
    
    function transitionRandomWithdrawal() internal {
        address user = depositors[_randInt(0, depositors.length - 1)];
        uint256 amount = calc_random_amount_d18();
        vm.startPrank(user);
        IERC20(wsteth).safeIncreaseAllowance(
            address(mellowSymbioticVault),
            amount
        );
    
        if (amount > depositedAmounts[_indexOf(user)]) {
            vm.expectRevert();
            mellowSymbioticVault.withdraw(amount, user, user);
        }  else {
            mellowSymbioticVault.withdraw(amount, user, user);
            depositedAmounts[_indexOf(user)] -= amount;
        }
        vm.stopPrank();
    }

    function transitionRandomClaim() internal {  
        address user = depositors[_randInt(0, depositors.length - 1)];
        vm.startPrank(user);
        mellowSymbioticVault.claim(user, user, type(uint256).max);

        vm.stopPrank();
    }

    function transitionRandomLimitIncrease() internal {
        address user = depositors[_randInt(0, depositors.length - 1)];
        uint256 newLimit = limit + calc_random_amount_d18();
        vm.startPrank(admin);
        mellowSymbioticVault.grantRole(SET_LIMIT_ROLE, admin);
        mellowSymbioticVault.setLimit(newLimit);
        limit = newLimit;
        vm.stopPrank();
    }

    function transitionPushIntoSymbiotic() internal {
        address user = depositors[_randInt(0, depositors.length - 1)];
        vm.startPrank(user);
        mellowSymbioticVault.pushIntoSymbiotic();
        vm.stopPrank();
    }

    function transitionRandomSlashing() internal {
        vm.startPrank(symbioticVault.slasher());
        uint256 slashedAmount = calc_random_amount_d18();
        symbioticVault.onSlash(slashedAmount, uint48(block.timestamp));
        vm.stopPrank();
    }

    function transitionFarm() internal {
        address user = depositors[_randInt(0, depositors.length - 1)];
        vm.startPrank(vaultAdmin);

        uint256 amount = 1;
        
        defaultStakerRewards.distributeRewards(
            wsteth, rewardToken1, amount, ""
        );
        
        vm.stopPrank();
    }

    function createDefaultStakerRewards() internal returns (MockDefaultStakerRewards) {
        SymbioticHelper.SymbioticDeployment memory deployment = symbioticHelper.getSymbioticDeployment();
        MockDefaultStakerRewards defaultStakerRewards = new MockDefaultStakerRewards(
            deployment.vaultFactory,
            deployment.networkRegistry,
            deployment.networkMiddlewareService
        );
        IDefaultStakerRewards.InitParams memory params = IDefaultStakerRewards.InitParams({
            vault: address(symbioticVault),
            adminFee: 0,
            defaultAdminRoleHolder: vaultAdmin,
            adminFeeClaimRoleHolder: vaultAdmin,
            adminFeeSetRoleHolder: vaultAdmin
        });
        
        defaultStakerRewards.initialize(params);
        return defaultStakerRewards;
    }

    function randomTransition() internal {
        randomTransition(2 ** nTransitions - 1);
    }

    function randomTransition(uint256 transitoinSubset) internal {
        require((transitoinSubset & (2 ** nTransitions - 1)) > 0);

        uint256 transitionIdx = _randInt(0, nTransitions - 1);
        while (((transitoinSubset >> transitionIdx) & 1) != 1) {
            transitionIdx =  _randInt(0, nTransitions - 1);
        }
        transitionByIndex(transitionIdx);
    }

    function transitionByIndex(uint256 transitionIdx) internal {
        require(transitionIdx < nTransitions);
        if (transitionIdx == 0) {
            transitionRandomDeposit();
        }
        if (transitionIdx == 1) {
            transitionRandomWithdrawal();
        }
        if (transitionIdx == 2) {
            transitionRandomLimitIncrease();
        }
        if (transitionIdx == 3) {
            transitionRandomClaim();
        }
        if (transitionIdx == 4) {
            transitionPushIntoSymbiotic();
        }
        if (transitionIdx == 5) {
            transitionRandomSlashing();
        }
        if (transitionIdx == 6) {
            transitionFarm();
        }
    }

    function finilizeTest() internal {
        transitionPushIntoSymbiotic();
        for (uint256 i = 0; i < depositors.length; i++) {
            address user;
            user = depositors[i];
            vm.startPrank(user);
            mellowSymbioticVault.claim(user, user, type(uint256).max);

            vm.stopPrank();
        }
    }

    function finalValidation() internal {
        for (uint256 i = 0; i < depositors.length; i++) {
            assert(depositedAmounts[i] <= limit);
        }
    }

    function _random() internal returns (uint256) {
        seed = uint256(
            keccak256(abi.encodePacked(block.timestamp, block.prevrandao, seed))
        );
        return seed;
    }

    function _randInt(uint256 maxValue) internal returns (uint256) {
        return _random() % (maxValue + 1);
    }

    function _randInt(
        uint256 minValue,
        uint256 maxValue
    ) internal returns (uint256) {
        return (_random() % (maxValue - minValue + 1)) + minValue;
    }

    function random_float_x96(
        uint256 minValue,
        uint256 maxValue
    ) internal returns (uint256) {
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
            uint256 b_x96 = random_float_x96(1e0, 1e6);
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
}
