// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";
import "../../src/interfaces/vaults/IVaultControl.sol";
import "../../src/VaultControl.sol";
import "../../scripts/mainnet/FactoryDeploy.sol";

contract SolvencyTest is BaseTest {
    using SafeERC20 for IERC20;

    uint256 ITER = 1000;
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
    uint48 epochDuration = 3600;

    uint256 symbioticLimit = 1e16 ether;
    ISymbioticVault symbioticVault;
    MellowSymbioticVault mellowSymbioticVault;

    uint256 limit = 1e8 ether;
    address[] public depositors;
    uint256[] public depositedAmounts;
    uint256[] public withdrawnAmounts;

    function testRunSolvency() external {
        deploy();

        addRandomUser();

        for (uint256 i = 0; i < ITER; i++) {
            randomTransition();
        }

        finilizeTest();
        finalValidation();
    }

    function deploy() public {
        symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: vaultOwner,
                    vaultAdmin: vaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    isDepositLimit: false,
                    depositLimit: symbioticLimit
                })
            )
        );

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

    function randomTransition() internal {
        uint256 nTransitions = 5;
        uint256 transitionIdx = _randInt(0, nTransitions - 1);
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
