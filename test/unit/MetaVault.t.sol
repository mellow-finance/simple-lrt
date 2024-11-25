// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";

import "../../src/strategies/DefaultDepositStrategy.sol";

import "../../src/strategies/DefaultRebalanceStrategy.sol";
import "../../src/strategies/DefaultWithdrawalStrategy.sol";

import "../../src/MultiVault.sol";
import {MultiDepositStrategy} from "../../src/strategies/MultiDepositStrategy.sol";
import {MultiWithdrawalStrategy} from "../../src/strategies/MultiWithdrawalStrategy.sol";

contract Unit is BaseTest {
    MetaVault vault;

    IdleVault idleVault;

    DefaultDepositStrategy depositStrategy;
    DefaultWithdrawalStrategy withdrawalStrategy;
    DefaultRebalanceStrategy rebalanceStrategy;

    MultiVault multiVault;
    MultiDepositStrategy multiDepositStrategy;
    MultiWithdrawalStrategy multiWithdrawalStrategy;

    address admin = address(1243);
    address wsteth = Constants.HOLESKY_WSTETH;

    function _testMetaVault() internal {
        vault = new MetaVault(bytes32("MetaVault"), 1);

        idleVault = new IdleVault();

        idleVault.initialize(
            IIdleVault.InitParams({
                asset: wsteth,
                limit: 0,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                admin: admin,
                name: "IdleVault",
                symbol: "IV"
            })
        );

        depositStrategy = new DefaultDepositStrategy();
        withdrawalStrategy = new DefaultWithdrawalStrategy();
        rebalanceStrategy = new DefaultRebalanceStrategy();

        vault.initialize(
            IMetaVault.InitParams({
                depositStrategy: address(depositStrategy),
                withdrawalStrategy: address(withdrawalStrategy),
                rebalanceStrategy: address(rebalanceStrategy),
                idleVault: address(idleVault),
                asset: wsteth,
                limit: type(uint256).max,
                admin: admin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MetaVault",
                symbol: "MV"
            })
        );

        Claimer claimer = new Claimer();

        vm.startPrank(admin);
        vault.grantRole(keccak256("ADD_SUBVAULT"), admin);

        IMellowSymbioticVault.InitParams memory msvInit;
        for (uint256 i = 0; i < 11; i++) {
            MellowSymbioticVault msv1 = new MellowSymbioticVault(bytes32("MellowSymbioticVault"), 1);
            address symbioticVault = symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: admin,
                    vaultAdmin: admin,
                    epochDuration: 7 days,
                    asset: wsteth,
                    isDepositLimit: false,
                    depositLimit: 0
                })
            );
            msvInit = IMellowSymbioticVault.InitParams({
                limit: 1000,
                symbioticCollateral: Constants.HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL,
                symbioticVault: symbioticVault,
                withdrawalQueue: address(
                    new SymbioticWithdrawalQueue(address(msv1), symbioticVault, address(claimer))
                ),
                admin: admin,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVault",
                symbol: "MSV"
            });

            msv1.initialize(msvInit);
            vault.addSubvault(address(msv1), true);
        }
        {
            MellowSymbioticVault msv2 = new MellowSymbioticVault(bytes32("MellowSymbioticVault"), 1);
            address symbioticVault = symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: admin,
                    vaultAdmin: admin,
                    epochDuration: 7 days,
                    asset: wsteth,
                    isDepositLimit: false,
                    depositLimit: 0
                })
            );
            msvInit.limit = type(uint256).max;
            msvInit.withdrawalQueue = address(
                new SymbioticWithdrawalQueue(address(msv2), symbioticVault, address(claimer))
            );
            msvInit.symbioticVault = symbioticVault;
            msv2.initialize(msvInit);
            vault.addSubvault(address(msv2), true);
        }
        vm.stopPrank();

        address user = address(1234213);
        uint256 amount = 1 gwei;
        deal(wsteth, user, amount * 1000);

        vm.startPrank(user);
        IERC20(wsteth).approve(address(vault), type(uint256).max);
        uint256 iter = 25;
        for (uint256 i = 0; i < iter; i++) {
            uint256 ind = rnd() % 2;
            if (ind == 0) {
                vault.deposit(amount, user);
            } else {
                vault.redeem(Math.min(amount, vault.balanceOf(user)), user, user);
            }
        }

        vm.stopPrank();
    }

    function _testMultiVault() internal {
        multiVault = new MultiVault(bytes32("MetaVault"), 1);
        multiDepositStrategy = new MultiDepositStrategy();
        multiWithdrawalStrategy = new MultiWithdrawalStrategy();
        rebalanceStrategy = new DefaultRebalanceStrategy();

        multiVault.initialize(
            IMultiVault.InitParams({
                admin: admin,
                limit: type(uint256).max,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                asset: wsteth,
                name: "MultiVault",
                symbol: "MV",
                depositStrategy: address(multiDepositStrategy),
                withdrawalStrategy: address(multiWithdrawalStrategy),
                rebalanceStrategy: address(rebalanceStrategy),
                symbioticDefaultCollateral: Constants.HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL,
                eigenLayerStrategyManager: address(0),
                eigenLayerRewardsCoordinator: address(0)
            })
        );

        Claimer claimer = new Claimer();

        uint256 symbioticSubvaults = 12;

        for (uint256 i = 0; i < symbioticSubvaults; i++) {
            address symbioticVault = symbioticHelper.createNewSymbioticVault(
                SymbioticHelper.CreationParams({
                    vaultOwner: admin,
                    vaultAdmin: admin,
                    epochDuration: 7 days,
                    asset: wsteth,
                    isDepositLimit: true,
                    depositLimit: i + 1 < symbioticSubvaults ? 1000 : type(uint256).max
                })
            );
            address withdrawalQueue = address(
                new SymbioticWithdrawalQueue(address(multiVault), symbioticVault, address(claimer))
            );

            vm.prank(admin);
            multiVault.addSubvault(
                symbioticVault, withdrawalQueue, IMultiVaultStorage.SubvaultType.SYMBIOTIC
            );
        }

        address user = address(1234213);
        uint256 amount = 1 gwei;
        deal(wsteth, user, amount * 1000);

        vm.startPrank(user);
        IERC20(wsteth).approve(address(multiVault), type(uint256).max);
        uint256 iter = 25;
        for (uint256 i = 0; i < iter; i++) {
            uint256 ind = rnd() % 2;
            if (ind == 0) {
                multiVault.deposit(amount, user);
            } else {
                multiVault.redeem(Math.min(amount, multiVault.balanceOf(user)), user, user);
            }
        }

        vm.stopPrank();
    }

    function testMultiVsMetaVault() external {
        for (uint256 seed = 1; seed <= 5; seed++) {
            _seed = seed;
            _testMetaVault();
            _seed = seed;
            _testMultiVault();
        }
    }

    uint256 _seed;

    function rnd() internal returns (uint256) {
        return _seed = uint256(keccak256(abi.encodePacked(_seed)));
    }
}
