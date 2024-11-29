// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "../src/adapters/ERC4626Adapter.sol";
import "../src/adapters/EigenLayerAdapter.sol";
import "../src/adapters/SymbioticAdapter.sol";

import "../src/strategies/RatiosStrategy.sol";
import "../src/utils/Claimer.sol";
import "../src/vaults/MultiVault.sol";

import {IDelegatorFactory} from "@symbiotic/core/interfaces/IDelegatorFactory.sol";
import {INetworkRegistry} from "@symbiotic/core/interfaces/INetworkRegistry.sol";
import {IOperatorRegistry} from "@symbiotic/core/interfaces/IOperatorRegistry.sol";
import {ISlasherFactory} from "@symbiotic/core/interfaces/ISlasherFactory.sol";
import {IVaultConfigurator} from "@symbiotic/core/interfaces/IVaultConfigurator.sol";
import {IVaultFactory} from "@symbiotic/core/interfaces/IVaultFactory.sol";
import {
    IBaseDelegator,
    IFullRestakeDelegator
} from "@symbiotic/core/interfaces/delegator/IFullRestakeDelegator.sol";

import {IVaultConfigurator} from "@symbiotic/core/interfaces/IVaultConfigurator.sol";
import {INetworkMiddlewareService} from
    "@symbiotic/core/interfaces/service/INetworkMiddlewareService.sol";
// import {ISlasher} from "@symbiotic/core/interfaces/slasher/ISlasher.sol";
import {IVault} from "@symbiotic/core/interfaces/vault/IVault.sol";

import {DefaultStakerRewards} from
    "@symbiotic/rewards/contracts/defaultStakerRewards/DefaultStakerRewards.sol";
import {IDefaultStakerRewards} from
    "@symbiotic/rewards/interfaces/defaultStakerRewards/IDefaultStakerRewards.sol";

contract MultiVaultTest is Test {
    string private constant NAME = "MultiVaultTest";
    uint256 private constant VERSION = 1;

    address private admin = vm.createWallet("multi-vault-admin").addr;
    uint256 private limit = 1000 ether;
    address private wsteth = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;
    address private vaultConfigurator = 0xD2191FE92987171691d552C219b8caEf186eb9cA;

    struct CreationParams {
        address vaultOwner;
        address vaultAdmin;
        uint48 epochDuration;
        address asset;
        bool isDepositLimit;
        uint256 depositLimit;
    }

    function generateAddress(string memory key) internal returns (address) {
        return vm.createWallet(key).addr;
    }

    function createNewSymbioticVault(CreationParams memory params)
        public
        returns (address symbioticVault)
    {
        IFullRestakeDelegator.InitParams memory initParams = IFullRestakeDelegator.InitParams({
            baseParams: IBaseDelegator.BaseParams({
                defaultAdminRoleHolder: generateAddress("defaultAdminRoleHolder"),
                hook: address(0),
                hookSetRoleHolder: generateAddress("hookSetRoleHolder")
            }),
            networkLimitSetRoleHolders: new address[](0),
            operatorNetworkLimitSetRoleHolders: new address[](0)
        });
        (symbioticVault,,) = IVaultConfigurator(vaultConfigurator).create(
            IVaultConfigurator.InitParams({
                version: 1,
                owner: params.vaultOwner,
                vaultParams: abi.encode(
                    IVault.InitParams({
                        collateral: params.asset,
                        burner: address(0),
                        epochDuration: params.epochDuration,
                        depositWhitelist: false,
                        isDepositLimit: params.isDepositLimit,
                        depositLimit: params.depositLimit,
                        defaultAdminRoleHolder: params.vaultAdmin,
                        depositWhitelistSetRoleHolder: params.vaultAdmin,
                        depositorWhitelistRoleHolder: params.vaultAdmin,
                        isDepositLimitSetRoleHolder: params.vaultAdmin,
                        depositLimitSetRoleHolder: params.vaultAdmin
                    })
                ),
                delegatorIndex: 0,
                delegatorParams: abi.encode(initParams),
                withSlasher: false,
                slasherIndex: 0,
                slasherParams: ""
            })
        );
    }

    function testMultiVault() public {
        MultiVault mv = new MultiVault(bytes32("MultiVaultTest"), VERSION);

        Claimer claimer = new Claimer();
        SymbioticAdapter symbioticAdapter = new SymbioticAdapter(address(mv), address(claimer));
        // EigenLayerAdapter eigenLayerAdapter = new EigenLayerAdapter();
        // ERC4626Adapter erc4626Adapter = new ERC4626Adapter();

        address symbioticVault = createNewSymbioticVault(
            CreationParams({
                vaultOwner: admin,
                vaultAdmin: admin,
                epochDuration: 1 days,
                asset: wsteth,
                isDepositLimit: false,
                depositLimit: 0
            })
        );

        RatiosStrategy strategy = new RatiosStrategy();

        mv.initialize(
            IMultiVault.InitParams({
                admin: admin,
                limit: limit,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                asset: wsteth,
                name: NAME,
                symbol: NAME,
                depositStrategy: address(strategy),
                withdrawalStrategy: address(strategy),
                rebalanceStrategy: address(strategy),
                defaultCollateral: address(0),
                symbioticAdapter: address(symbioticAdapter),
                eigenLayerAdapter: address(0),
                erc4626Adapter: address(0)
            })
        );

        vm.startPrank(admin);

        mv.grantRole(keccak256("ADD_SUBVAULT_ROLE"), admin);
        mv.grantRole(keccak256("SHARES_STRATEGY_SET_RATIO_ROLE"), admin);
        mv.grantRole(keccak256("REBALANCE_ROLE"), admin);

        address[] memory subvaults = new address[](1);
        subvaults[0] = symbioticVault;
        RatiosStrategy.Ratio[] memory ratios = new RatiosStrategy.Ratio[](1);
        ratios[0].minRatioD18 = 0.94 ether;
        ratios[0].maxRatioD18 = 0.95 ether;

        mv.addSubvault(symbioticVault, IMultiVaultStorage.Protocol.SYMBIOTIC);
        strategy.setRatio(address(mv), subvaults, ratios);

        mv.rebalance();

        for (uint256 i = 0; i < 10; i++) {
            uint256 amount = 1 ether;
            deal(wsteth, admin, amount);
            IERC20(wsteth).approve(address(mv), amount);
            mv.deposit(amount, admin, admin);
            if (i == 0) {
                deal(wsteth, address(mv), IERC20(wsteth).balanceOf(address(mv)) * 5);
            }
            if (i == 9) {
                deal(wsteth, address(mv), 0);
            }
            mv.rebalance();

            mv.redeem(mv.balanceOf(admin), admin, admin);
        }

        vm.stopPrank();
    }
}
