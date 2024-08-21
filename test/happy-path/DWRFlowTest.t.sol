// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

contract Integration is BaseTest {
    /*
        forge test -vvvv  --match-path ./test/DWFlowTest.t.sol --fork-url $(grep HOLESKY_RPC .env | cut -d '=' -f2,3,4,5)  --fork-block-number 2160000
    */

    address admin = makeAddr("admin");
    address user = makeAddr("user");
    address limitIncreaser = makeAddr("limitIncreaser");

    uint64 vaultVersion = 1;
    address vaultOwner = makeAddr("vaultOwner");
    address vaultAdmin = makeAddr("vaultAdmin");
    uint48 epochDuration = 3600;
    address wsteth = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;

    address curatorTreasury = makeAddr("curatorTreasury");
    address rewardsDistributor = makeAddr("rewardsDistributor");

    function testRewards() external {
        require(block.chainid == 17000, "This test can only be run on the Holesky testnet");

        MellowSymbioticVault mellowSymbioticVault = new MellowSymbioticVault(bytes32(uint256(1)), 1);

        ISymbioticVault symbioticVault = ISymbioticVault(
            symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    limitIncreaser: limitIncreaser,
                    vaultOwner: vaultOwner,
                    vaultAdmin: vaultAdmin,
                    epochDuration: epochDuration,
                    asset: wsteth,
                    limit: 1 ether
                })
            )
        );
        SymbioticWithdrawalQueue withdrawalQueue =
            new SymbioticWithdrawalQueue(address(mellowSymbioticVault), address(symbioticVault));

        mellowSymbioticVault.initialize(
            IMellowSymbioticVault.InitParams({
                name: "MellowSymbioticVault",
                symbol: "MSV",
                symbioticVault: address(symbioticVault),
                withdrawalQueue: address(withdrawalQueue),
                admin: admin,
                limit: 1000 ether,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false
            })
        );

        address token = withdrawalQueue.symbioticVault().collateral();
        assertEq(token, wsteth);

        (address symbioticFarm, address distributionFarm) = symbioticHelper.createFarms(wsteth);

        vm.startPrank(admin);
        mellowSymbioticVault.grantRole(keccak256("SET_FARM_ROLE"), admin);
        mellowSymbioticVault.setFarm(
            0,
            IMellowSymbioticVaultStorage.FarmData({
                rewardToken: wsteth,
                symbioticFarm: symbioticFarm,
                distributionFarm: distributionFarm,
                curatorFeeD6: 1e5, // 10%
                curatorTreasury: curatorTreasury
            })
        );
        vm.stopPrank();

        vm.startPrank(user);

        uint256 amount = 0.5 ether;
        uint256 n = 25;

        deal(token, user, amount * n);
        IERC20(token).approve(address(mellowSymbioticVault), amount * n);

        for (uint256 i = 0; i < n; i++) {
            mellowSymbioticVault.deposit(amount, user);
        }
        for (uint256 i = 0; i < n; i++) {
            mellowSymbioticVault.withdraw(amount, user, user);
        }

        skip(epochDuration * 2);
        // extra ether
        vm.stopPrank();

        vm.startPrank(rewardsDistributor);
        deal(wsteth, rewardsDistributor, 1 ether);
        IERC20(wsteth).approve(symbioticFarm, 1 ether);
        MockStakingRewards(symbioticFarm).increaseRewards(
            address(mellowSymbioticVault), wsteth, 1 ether
        );
        vm.stopPrank();

        vm.startPrank(user);
        for (uint256 i = 0; i < n; i++) {
            mellowSymbioticVault.claim(user, user, amount);
        }

        mellowSymbioticVault.pushRewards(0, new bytes(0));

        assertEq(IERC20(wsteth).balanceOf(curatorTreasury), 0.1 ether);
        assertEq(IERC20(wsteth).balanceOf(distributionFarm), 0.9 ether);

        vm.stopPrank();
    }
}
