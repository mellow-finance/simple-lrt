// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

//Test for previous version: https://github.com/mellow-finance/mellow-lrt/blob/fixes/audit-sherlock-fixes/tests/mainnet/e2e/SolvencyTest.t.sol

contract SolvencyTest is BaseTest {
    using SafeERC20 for IERC20;
    /*
        1. functions for random values
        2. transitions: deposit, withdraw, claim, slash, param changes, e.t.c, rewards, push rewards, push into symbiotic
        3. validation funciton. totalAssets <= limit, ...
        4. finalization
        5. final_validation 
    */
    address admin = makeAddr("admin");
    address user = makeAddr("user");

    uint256 private seed;

    uint256 public constant MAX_ERROR = 10 wei;
    uint256 public constant Q96 = 2 ** 96;
    uint256 public constant D18 = 1e18;

    address wsteth = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;
    address steth = 0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034;
    address weth = 0x94373a4919B3240D86eA41593D5eBa789FEF3848;
    
    address limitIncreaser = makeAddr("limitIncreaser");

    uint64 vaultVersion = 1;
    address vaultOwner = makeAddr("vaultOwner");
    address vaultAdmin = makeAddr("vaultAdmin");
    uint48 epochDuration = 3600;

    uint256 symbioticLimit = 1000 ether;

    MellowSymbioticVault singleton;
    MellowSymbioticVaultFactory factory;
    ISymbioticVault symbioticVault;
    IMellowSymbioticVault mellowSymbioticVault;
    IWithdrawalQueue withdrawalQueue;

    address[] public depositors;
    uint256[] public depositedAmounts;
    uint256[] public withdrawnAmounts;

    function deploy() public {
        /*
            1. deploy
            2. random transitions + validation
            3. finalization
            4. final validation
        */

        singleton = new MellowSymbioticVault("MellowSymbioticVault", 1);
        factory = new MellowSymbioticVaultFactory(address(singleton));

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

        (mellowSymbioticVault, withdrawalQueue) = factory
            .create(
            IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: makeAddr("proxyAdmin"),
                limit: 1e8 ether,
                symbioticVault: address(symbioticVault),
                admin: admin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            })
        );
    }

    function transition_random_deposit() internal {
        address user;
        if (depositors.length == 0 || random_bool()) {
            user = random_address();
            depositors.push(user);
            depositedAmounts.push(0);
            withdrawnAmounts.push(0);
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

        mellowSymbioticVault.deposit(amount, user, address(0));
        vm.stopPrank();

        depositedAmounts[_indexOf(user)] += amount;
    }
    
    function transition_random_withdrawal() internal {
        address user;
        if (depositors.length == 0 || random_bool()) {
            user = random_address();
            depositors.push(user);
            depositedAmounts.push(0);
            withdrawnAmounts.push(0);
        } else {
            user = depositors[_randInt(0, depositors.length - 1)];
        }
        uint256 amount = calc_random_amount_d18();
        deal(wsteth, user, amount);
        vm.startPrank(user);
        IERC20(wsteth).safeIncreaseAllowance(
            address(mellowSymbioticVault),
            1e8
        );

        mellowSymbioticVault.deposit(1e7, user, address(0));
        mellowSymbioticVault.withdraw(amount, user, address(0));
        vm.stopPrank();

        depositedAmounts[_indexOf(user)] += 1e7 - amount;
    }


    function finilizeTest() internal {

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

    function testRunSolvency() external {
        deploy();

        seed = 42;

        transition_random_deposit();
        transition_random_withdrawal();
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
