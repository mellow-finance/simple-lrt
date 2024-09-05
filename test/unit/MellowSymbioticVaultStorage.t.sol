// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

import "../mocks/MockMellowSymbioticVaultStorage.sol";

contract Unit is BaseTest {
    address wsteth = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;
    address steth = 0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034;
    address weth = 0x94373a4919B3240D86eA41593D5eBa789FEF3848;
    address admin = makeAddr("admin");
    address user = makeAddr("user");
    address limitIncreaser = makeAddr("limitIncreaser");

    uint64 vaultVersion = 1;
    address vaultOwner = makeAddr("vaultOwner");
    address vaultAdmin = makeAddr("vaultAdmin");
    uint48 epochDuration = 3600;
    uint256 symbioticLimit = 1000 ether;

    function testConstructor() external {
        MockMellowSymbioticVaultStorage c =
            new MockMellowSymbioticVaultStorage(keccak256("name"), 1);
        assertNotEq(address(c), address(0));
    }

    function testInitializeMellowSymbioticVaultStorage() external {
        MockMellowSymbioticVaultStorage c =
            new MockMellowSymbioticVaultStorage(keccak256("name"), 1);

        ISymbioticVault symbioticVault = ISymbioticVault(
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

        address mockWithdrawalQueue = makeAddr("mockWithdrawalQueue");

        vm.recordLogs();
        c.initializeMellowSymbioticVaultStorage(
            address(wstethSymbioticCollateral), address(symbioticVault), mockWithdrawalQueue
        );
        Vm.Log[] memory events = vm.getRecordedLogs();

        assertEq(events.length, 4);

        bytes32[4] memory expectedEvents = [
            keccak256("SymbioticCollateralSet(address,uint256)"),
            keccak256("SymbioticVaultSet(address,uint256)"),
            keccak256("WithdrawalQueueSet(address,uint256)"),
            keccak256("Initialized(uint64)")
        ];

        for (uint256 i = 0; i < 3; i++) {
            assertEq(events[i].emitter, address(c));
            assertEq(events[i].topics[0], expectedEvents[i]);
        }

        assertEq(address(c.withdrawalQueue()), mockWithdrawalQueue);
        assertEq(address(c.symbioticVault()), address(symbioticVault));
        assertEq(address(c.symbioticCollateral()), address(wstethSymbioticCollateral));
        assertEq(c.symbioticFarmIds().length, 0);
        assertEq(c.symbioticFarmCount(), 0);

        vm.expectRevert();
        c.symbioticFarmIdAt(0);
    }

    function testSetFarm() external {
        MockMellowSymbioticVaultStorage c =
            new MockMellowSymbioticVaultStorage(keccak256("name"), 1);

        address mockSymbioticVault = makeAddr("mockSymbioticVault");
        address mockWithdrawalQueue = makeAddr("mockWithdrawalQueue");
        c.initializeMellowSymbioticVaultStorage(
            address(wstethSymbioticCollateral), mockSymbioticVault, mockWithdrawalQueue
        );

        address rewardToken1 = makeAddr("rewardToken1");
        address symbioticFarm1 = makeAddr("symbioticFarm1");
        address distributionFarm1 = makeAddr("distributionFarm1");
        address curatorTreasury1 = makeAddr("curatorTreasury1");
        uint256 curatorFeeD6_1 = 1e6;

        c.setFarm(
            1,
            IMellowSymbioticVaultStorage.FarmData({
                rewardToken: rewardToken1,
                symbioticFarm: symbioticFarm1,
                distributionFarm: distributionFarm1,
                curatorTreasury: curatorTreasury1,
                curatorFeeD6: curatorFeeD6_1
            })
        );

        assertTrue(c.symbioticFarmsContains(1));
        assertFalse(c.symbioticFarmsContains(2));

        IMellowSymbioticVaultStorage.FarmData memory farmData = c.symbioticFarm(1);
        assertEq(farmData.rewardToken, rewardToken1);
        assertEq(farmData.symbioticFarm, symbioticFarm1);
        assertEq(farmData.distributionFarm, distributionFarm1);
        assertEq(farmData.curatorTreasury, curatorTreasury1);
        assertEq(farmData.curatorFeeD6, curatorFeeD6_1);

        assertEq(c.symbioticFarmIds().length, 1);
        assertEq(c.symbioticFarmCount(), 1);
        assertEq(c.symbioticFarmIdAt(0), 1);

        address rewardToken2 = makeAddr("rewardToken2");
        address symbioticFarm2 = makeAddr("symbioticFarm2");
        address distributionFarm2 = makeAddr("distributionFarm2");
        address curatorTreasury2 = makeAddr("curatorTreasury2");
        uint256 curatorFeeD6_2 = 2e6;

        c.setFarm(
            2,
            IMellowSymbioticVaultStorage.FarmData({
                rewardToken: rewardToken2,
                symbioticFarm: symbioticFarm2,
                distributionFarm: distributionFarm2,
                curatorTreasury: curatorTreasury2,
                curatorFeeD6: curatorFeeD6_2
            })
        );

        farmData = c.symbioticFarm(2);
        assertEq(farmData.rewardToken, rewardToken2);
        assertEq(farmData.symbioticFarm, symbioticFarm2);
        assertEq(farmData.distributionFarm, distributionFarm2);
        assertEq(farmData.curatorTreasury, curatorTreasury2);
        assertEq(farmData.curatorFeeD6, curatorFeeD6_2);

        assertEq(c.symbioticFarmIds().length, 2);
        assertEq(c.symbioticFarmCount(), 2);
        assertEq(c.symbioticFarmIdAt(0), 1);
        assertEq(c.symbioticFarmIdAt(1), 2);

        c.setFarm(
            1,
            IMellowSymbioticVaultStorage.FarmData({
                rewardToken: address(0),
                symbioticFarm: address(0),
                distributionFarm: address(0),
                curatorTreasury: address(0),
                curatorFeeD6: 0
            })
        );

        assertEq(c.symbioticFarmIds().length, 1);
        assertEq(c.symbioticFarmCount(), 1);
        assertEq(c.symbioticFarmIdAt(0), 2);
    }
}
