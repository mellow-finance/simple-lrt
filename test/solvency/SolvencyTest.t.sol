// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";
import "../../src/interfaces/vaults/IVaultControl.sol";
import "../../src/VaultControl.sol";
import "../../scripts/mainnet/FactoryDeploy.sol";

import {IStakerRewards} from "@symbiotic/rewards/interfaces/stakerRewards/IStakerRewards.sol";
import {IDefaultStakerRewards} from "@symbiotic/rewards/interfaces/defaultStakerRewards/IDefaultStakerRewards.sol";
import {MockDefaultStakerRewards} from "../mocks/MockDefaultStakerRewards.sol";

import {NetworkRegistry} from "@symbiotic/core/contracts/NetworkRegistry.sol";
import {NetworkMiddlewareService} from "@symbiotic/core/contracts/service/NetworkMiddlewareService.sol";

import {Token} from "@symbiotic/core-test/mocks/Token.sol";

contract SolvencyTest is BaseTest {
    using SafeERC20 for IERC20;

    uint256 ITER = 50;
    bytes32 private constant SET_LIMIT_ROLE = keccak256("SET_LIMIT_ROLE");

    address admin = makeAddr("admin");

    uint256 private seed = 42; 

    uint256 public constant MAX_ERROR = 10 wei;
    uint256 public constant Q96 = 2 ** 96;
    uint256 public constant D18 = 1e18;

    address wsteth = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;
    address steth = 0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034;
    address weth = 0x94373a4919B3240D86eA41593D5eBa789FEF3848;

    address vaultOwner = makeAddr("vaultOwner");
    address vaultAdmin = makeAddr("vaultAdmin");
    address proxyAdmin = makeAddr("proxyAdmin");
    address mellowVaultAdmin = makeAddr("mellowVaultAdmin");
    address burner = makeAddr("burner");
    uint48 epochDuration = 3600;
    address bob = makeAddr("bob");

    IERC20 rewardToken;
    IERC20 token;

    event Log(string message);

    uint256 symbioticLimit;
    ISymbioticVault symbioticVault;
    MellowSymbioticVault mellowSymbioticVault;

    uint256 limit;
    address[] public depositors;
    uint256[] public depositedAmounts;
    uint256[] public slashedAmounts;
    uint256 totalSlashedAmount = 0;
    uint256 totalDepositedAmount = 0;
    EthWrapper ethereumWrapper = new EthWrapper(weth, wsteth, steth);
    address[] ethTokens = [
        ethereumWrapper.ETH(), 
        ethereumWrapper.wstETH(), 
        ethereumWrapper.stETH(),
        ethereumWrapper.WETH()
    ];

    function()[] transitions = [
        transitionRandomDeposit,
        transitionRandomWithdrawal, 
        transitionRandomLimitIncrease,
        transitionRandomClaim,
        transitionPushIntoSymbiotic,
        transitionRandomSlashing,
        transitionRandomFarm
    ];

    uint256 nTransitions = transitions.length;

    MockDefaultStakerRewards defaultStakerRewards;

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

    function testFuzz_TransitonBitmask(uint256 iter, uint256 _limit, uint256 _symbioticLimit, uint256 transitionSubset) external {
        deploy(_limit, _symbioticLimit);

        addRandomUser();
        for (uint256 i = 0; i < iter; i++) {
            randomTransition(transitionSubset);
        }

        finilizeTest();
        finalValidation();
    }

    function testFuzz_TrasitionList(uint256[] memory transitionIndexes, uint256 _limit, uint256 _symbioticLimit) external {
        deploy(_limit, _symbioticLimit);

        addRandomUser();
        for (uint256 i = 0; i < transitionIndexes.length; i++) {
            transitionByIndex(transitionIndexes[i]);
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
        
        rewardToken = IERC20(new Token("RewardToken"));
        defaultStakerRewards = createDefaultStakerRewards();
    }

    function addRandomUser() internal returns (address)  {
        address user = random_address();
        depositors.push(user);
        depositedAmounts.push(0);
        slashedAmounts.push(0);
        return user;
    }

    function transitionRandomDeposit() internal {
        emit Log("transitionRandomDeposit");

        address user;
        if (random_bool()) {
            user = addRandomUser();
        } else {
            user = depositors[_randInt(0, depositors.length - 1)];
        }
        uint256 amount = calc_random_amount_d18();
        

        address token;
        if (random_bool()) {
            uint256 tokenIdx = _randInt(0, ethTokens.length - 1);
            token = ethTokens[tokenIdx];
        } else {
            token = wsteth;
        }

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
            totalDepositedAmount += amount;
        }
        vm.stopPrank();
    }
    
    function transitionRandomWithdrawal() internal {
        emit Log("transitionRandomWithdrawal");

        address user = depositors[_randInt(0, depositors.length - 1)];
        uint256 amount = calc_random_amount_d18();
        vm.startPrank(user);
        IERC20(wsteth).safeIncreaseAllowance(
            address(mellowSymbioticVault),
            amount
        );
        uint256 availableAmount = depositedAmounts[_indexOf(user)] - slashedAmounts[_indexOf(user)];
        if (amount > availableAmount) {
            vm.expectRevert();
            mellowSymbioticVault.withdraw(amount, user, user);
        }  else {
            mellowSymbioticVault.withdraw(amount, user, user);
            depositedAmounts[_indexOf(user)] -= amount;
        }
        vm.stopPrank();
    }

    function transitionRandomClaim() internal {  
        emit Log("transitionRandomClaim");

        address user = depositors[_randInt(0, depositors.length - 1)];
        vm.startPrank(user);
        mellowSymbioticVault.claim(user, user, type(uint256).max);

        vm.stopPrank();
    }

    function transitionRandomLimitIncrease() internal {
        emit Log("transitionRandomLimitIncrease");

        address user = depositors[_randInt(0, depositors.length - 1)];
        uint256 newLimit = limit + calc_random_amount_d18();
        vm.startPrank(admin);
        mellowSymbioticVault.grantRole(SET_LIMIT_ROLE, admin);
        mellowSymbioticVault.setLimit(newLimit);
        limit = newLimit;
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

        vm.startPrank(symbioticVault.slasher());
        uint256 slashedAmount = calc_random_amount_d18();
        symbioticVault.onSlash(slashedAmount, uint48(block.timestamp));
        
        slashedAmount = Math.min(totalSlashedAmount + slashedAmount, totalDepositedAmount) - totalSlashedAmount;
        uint256 totalAvailableAmount = totalDepositedAmount - totalSlashedAmount;
        for (uint256 i = 0; i < depositors.length; i++) {
            uint256 availableAmount = depositedAmounts[i] - slashedAmounts[i];
            slashedAmounts[i] += Math.mulDiv(
                slashedAmount, 
                availableAmount, 
                Math.max(1, totalAvailableAmount)
            );
        }
        totalSlashedAmount += slashedAmount;
        vm.stopPrank();
    }

    function transitionRandomFarm() internal {
        emit Log("transitionRandomFarm");

        address network = bob;
        uint256 distributeAmount = _randInt(1, 1 ether);
        
        _distributeRewards(
            bob,
            network,
            address(rewardToken),
            distributeAmount,
            uint48(block.timestamp),
            type(uint256).max,
            "",
            ""
        );
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
        
        address network = bob;
        _registerNetwork(network, bob);
        
        uint256 amount = 100_000 * 1e18;
        rewardToken.transfer(bob, 100_000 ether);
        vm.startPrank(bob);
        rewardToken.approve(address(defaultStakerRewards), type(uint256).max);

        IERC20(rewardToken).safeIncreaseAllowance(
            address(bob),
            amount
        );
        IERC20(rewardToken).safeIncreaseAllowance(
            address(defaultStakerRewards),
            amount
        );
        vm.stopPrank();

        return defaultStakerRewards;
    }

    function _distributeRewards(
        address user,
        address network,
        address token,
        uint256 amount,
        uint48 timestamp,
        uint256 maxAdminFee,
        bytes memory activeSharesHint,
        bytes memory activeStakeHint
    ) internal {
        vm.startPrank(user);
        defaultStakerRewards.distributeRewards(
            network, token, amount, abi.encode(timestamp, maxAdminFee, activeSharesHint, activeStakeHint)
        );
        vm.stopPrank();
    }

    function _registerNetwork(address user, address middleware) internal {
        SymbioticHelper.SymbioticDeployment memory deployment = symbioticHelper.getSymbioticDeployment();
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
            transitionIdx =  _randInt(0, nTransitions - 1);
        }
        transitionByIndex(transitionIdx);
    }

    function transitionByIndex(uint256 transitionIdx) internal {
        require(transitionIdx < nTransitions);
        return transitions[transitionIdx]();
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
