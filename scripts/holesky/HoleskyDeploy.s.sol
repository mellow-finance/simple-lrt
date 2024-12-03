// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {EthWrapper} from "../../src/EthWrapper.sol";
import "./FactoryDeploy.sol";
import {IDelegatorFactory} from "@symbiotic/core/interfaces/IDelegatorFactory.sol";

import {INetworkRegistry} from "@symbiotic/core/interfaces/INetworkRegistry.sol";
import {IOperatorRegistry} from "@symbiotic/core/interfaces/IOperatorRegistry.sol";
import {ISlasherFactory} from "@symbiotic/core/interfaces/ISlasherFactory.sol";
import {IVaultConfigurator} from "@symbiotic/core/interfaces/IVaultConfigurator.sol";
import {IVaultFactory} from "@symbiotic/core/interfaces/IVaultFactory.sol";
import {
    IBaseDelegator,
    IFullRestakeDelegator,
    IFullRestakeDelegator
} from "@symbiotic/core/interfaces/delegator/IFullRestakeDelegator.sol";
import {INetworkRestakeDelegator} from
    "@symbiotic/core/interfaces/delegator/INetworkRestakeDelegator.sol";
import {INetworkMiddlewareService} from
    "@symbiotic/core/interfaces/service/INetworkMiddlewareService.sol";

import {IBaseSlasher} from "@symbiotic/core/interfaces/slasher/IBaseSlasher.sol";
import {ISlasher} from "@symbiotic/core/interfaces/slasher/ISlasher.sol";
import {IVetoSlasher} from "@symbiotic/core/interfaces/slasher/IVetoSlasher.sol";
import {IVault} from "@symbiotic/core/interfaces/vault/IVault.sol";

contract Deploy is Script, FactoryDeploy {
    struct SlasherParams {
        bool withSlasher;
        uint64 slaherIndex;
        bytes slasherParams;
    }

    struct DelegatorParams {
        uint64 delegatorIndex;
        bytes delegatorParams;
    }

    address public constant HOLESKY_DEPLOYER = 0x7777775b9E6cE9fbe39568E485f5E20D1b0e04EE;

    address public constant HOLESKY_WSTETH = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;
    address public constant HOLESKY_STETH = 0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034;
    address public constant HOLESKY_WETH = 0x94373a4919B3240D86eA41593D5eBa789FEF3848;
    address public constant HOLESKY_WSTETH_DEFAULT_COLLATERAL =
        0x23E98253F372Ee29910e22986fe75Bb287b011fC;

    address public constant HOLESKY_VAULT_CONFIGURATOR = 0xD2191FE92987171691d552C219b8caEf186eb9cA;

    uint256 public constant HOLESKY_LIMIT = 10 ether;
    uint48 public constant HOLESKY_EPOCH_DURATION = 2 minutes;
    uint48 public constant HOLESKY_VETO_DURATION = 1 minutes;
    uint48 public constant HOLESKY_RESOLVER_SET_EPOCHS_DELAY = 1 minutes;

    function createSymbioticVault(
        SlasherParams memory slasherParams,
        DelegatorParams memory delegatorParams
    ) internal returns (address symbioticVault) {
        (symbioticVault,,) = IVaultConfigurator(HOLESKY_VAULT_CONFIGURATOR).create(
            IVaultConfigurator.InitParams({
                version: 1,
                owner: HOLESKY_DEPLOYER,
                vaultParams: abi.encode(
                    IVault.InitParams({
                        collateral: HOLESKY_WSTETH,
                        burner: address(0),
                        epochDuration: HOLESKY_EPOCH_DURATION,
                        depositWhitelist: false,
                        isDepositLimit: false,
                        depositLimit: 0,
                        defaultAdminRoleHolder: HOLESKY_DEPLOYER,
                        depositWhitelistSetRoleHolder: HOLESKY_DEPLOYER,
                        depositorWhitelistRoleHolder: HOLESKY_DEPLOYER,
                        isDepositLimitSetRoleHolder: HOLESKY_DEPLOYER,
                        depositLimitSetRoleHolder: HOLESKY_DEPLOYER
                    })
                ),
                delegatorIndex: delegatorParams.delegatorIndex,
                delegatorParams: delegatorParams.delegatorParams,
                withSlasher: slasherParams.withSlasher,
                slasherIndex: slasherParams.slaherIndex,
                slasherParams: slasherParams.slasherParams
            })
        );
    }

    function run() external {
        address[] memory holders = new address[](1);
        holders[0] = HOLESKY_DEPLOYER;

        DelegatorParams[2] memory delegatorParams = [
            DelegatorParams({
                delegatorIndex: 0,
                delegatorParams: abi.encode(
                    IFullRestakeDelegator.InitParams({
                        baseParams: IBaseDelegator.BaseParams({
                            defaultAdminRoleHolder: HOLESKY_DEPLOYER,
                            hook: address(0),
                            hookSetRoleHolder: HOLESKY_DEPLOYER
                        }),
                        networkLimitSetRoleHolders: holders,
                        operatorNetworkLimitSetRoleHolders: holders
                    })
                )
            }),
            DelegatorParams({
                delegatorIndex: 1,
                delegatorParams: abi.encode(
                    INetworkRestakeDelegator.InitParams({
                        baseParams: IBaseDelegator.BaseParams({
                            defaultAdminRoleHolder: HOLESKY_DEPLOYER,
                            hook: address(0),
                            hookSetRoleHolder: HOLESKY_DEPLOYER
                        }),
                        networkLimitSetRoleHolders: holders,
                        operatorNetworkSharesSetRoleHolders: holders
                    })
                )
            })
        ];

        SlasherParams[2] memory slasherParams = [
            SlasherParams({withSlasher: false, slaherIndex: 0, slasherParams: new bytes(0)}),
            SlasherParams({
                withSlasher: true,
                slaherIndex: 0,
                slasherParams: abi.encode(
                    IVetoSlasher.InitParams({
                        baseParams: IBaseSlasher.BaseParams({isBurnerHook: false}),
                        vetoDuration: HOLESKY_VETO_DURATION,
                        resolverSetEpochsDelay: HOLESKY_RESOLVER_SET_EPOCHS_DELAY
                    })
                )
            })
        ];

        vm.startBroadcast(uint256(bytes32(vm.envBytes("HOLESKY_DEPLOYER"))));

        FactoryDeploy.FactoryDeployParams memory factoryDeployParams = FactoryDeploy
            .FactoryDeployParams({
            deployer: HOLESKY_DEPLOYER,
            factory: address(0),
            singletonName: bytes32("holesky-test-deployment"),
            singletonVersion: 1,
            setFarmRoleHoler: address(0),
            setLimitRoleHolder: address(0),
            pauseWithdrawalsRoleHolder: address(0),
            unpauseWithdrawalsRoleHolder: address(0),
            pauseDepositsRoleHolder: address(0),
            unpauseDepositsRoleHolder: address(0),
            setDepositWhitelistRoleHolder: address(0),
            setDepositorWhitelistStatusRoleHolder: address(0),
            initParams: IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: HOLESKY_DEPLOYER,
                limit: HOLESKY_LIMIT,
                symbioticCollateral: HOLESKY_WSTETH_DEFAULT_COLLATERAL,
                symbioticVault: address(0),
                admin: HOLESKY_DEPLOYER,
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "",
                symbol: ""
            })
        });

        factoryDeployParams = FactoryDeploy.commonDeploy(factoryDeployParams);
        console2.log("MellowSymbioticVaultFactory:", factoryDeployParams.factory);
        EthWrapper ethWrapper = new EthWrapper(HOLESKY_WETH, HOLESKY_WSTETH, HOLESKY_STETH);
        console2.log("EthWrapper:", address(ethWrapper));

        string[6] memory names = [
            "MSV {FullRD} {None}",
            "MSV {FullRD} {Slasher}",
            "MSV {FullRD} {VetoSlasher}",
            "MSV {NetworkRD} {None}",
            "MSV {NetworkRD} {Slasher}",
            "MSV {NetworkRD} {VetoSlasher}"
        ];

        string[6] memory symbols = [
            "MSV {FullRD} {None}",
            "MSV {FullRD} {Slasher}",
            "MSV {FullRD} {VetoSlasher}",
            "MSV {NetworkRD} {None}",
            "MSV {NetworkRD} {Slasher}",
            "MSV {NetworkRD} {VetoSlasher}"
        ];

        uint256 amount = 1 gwei;

        for (uint256 i = 0; i < delegatorParams.length; i++) {
            for (uint256 j = 0; j < slasherParams.length; j++) {
                address symbioticVault = createSymbioticVault(slasherParams[j], delegatorParams[i]);
                factoryDeployParams.initParams.symbioticVault = symbioticVault;
                factoryDeployParams.initParams.name = names[i * 3 + j];
                factoryDeployParams.initParams.symbol = symbols[i * 3 + j];

                (IMellowSymbioticVault v_,) = FactoryDeploy.deploy(factoryDeployParams);
                MellowSymbioticVault vault = MellowSymbioticVault(address(v_));
                ethWrapper.deposit{value: amount}(
                    ethWrapper.ETH(), amount, address(vault), HOLESKY_DEPLOYER, HOLESKY_DEPLOYER
                );

                console2.log("%s: ", vault.name(), address(vault));
                console2.log("SymbioticWithdrawalQueue:", address(vault.withdrawalQueue()));
                console2.log("SymbioticVault:", symbioticVault);
                console2.log("--------------------");
            }
        }
        vm.stopBroadcast();

        revert("here");
    }
}
