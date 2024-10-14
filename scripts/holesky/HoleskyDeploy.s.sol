// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./FactoryDeploy.sol";
import "forge-std/Script.sol";

import {DelegatorFactory} from "@symbiotic/core/interfaces/DelegatorFactory.sol";
import {NetworkRegistry} from "@symbiotic/core/interfaces/NetworkRegistry.sol";
import {OperatorRegistry} from "@symbiotic/core/interfaces/OperatorRegistry.sol";
import {SlasherFactory} from "@symbiotic/core/interfaces/SlasherFactory.sol";
import {VaultConfigurator} from "@symbiotic/core/interfaces/VaultConfigurator.sol";
import {VaultFactory} from "@symbiotic/core/interfaces/VaultFactory.sol";
import {
    FullRestakeDelegator,
    IBaseDelegator,
    IFullRestakeDelegator
} from "@symbiotic/core/interfaces/delegator/FullRestakeDelegator.sol";

import {
    INetworkRestakeDelegator,
    NetworkRestakeDelegator
} from "@symbiotic/core/interfaces/delegator/NetworkRestakeDelegator.sol";

import {NetworkMiddlewareService} from
    "@symbiotic/core/interfaces/service/NetworkMiddlewareService.sol";
import {Slasher} from "@symbiotic/core/interfaces/slasher/Slasher.sol";
import {IVetoSlasher, VetoSlasher} from "@symbiotic/core/interfaces/slasher/VetoSlasher.sol";

import {Vault} from "@symbiotic/core/interfaces/vault/Vault.sol";

import {IVaultConfigurator} from "@symbiotic/core/interfaces/IVaultConfigurator.sol";
import {IVault} from "@symbiotic/core/interfaces/vault/IVault.sol";

import {EthWrapper} from "../../src/EthWrapper.sol";

contract Deploy is Script, FactoryDeploy {
    address public constant HOLESKY_DEPLOYER = 0x7777775b9E6cE9fbe39568E485f5E20D1b0e04EE;

    address public constant HOLESKY_WSTETH = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;
    address public constant HOLESKY_STETH = 0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034;
    address public constant HOLESKY_WETH = 0x94373a4919B3240D86eA41593D5eBa789FEF3848;
    address public constant HOLESKY_WSTETH_DEFAULT_COLLATERAL =
        0x23E98253F372Ee29910e22986fe75Bb287b011fC;

    address public constant HOLESKY_VAULT_CONFIGURATOR = 0x382e9c6fF81F07A566a8B0A3622dc85c47a891Df;

    uint256 public constant HOLESKY_LIMIT = 10 ether;
    uint48 public constant HOLESKY_EPOCH_DURATION = 2 minutes;
    uint48 public constant HOLESKY_VETO_DURATION = 1 minutes;
    uint48 public constant HOLESKY_RESOLVER_SET_EPOCHS_DELAY = 1 minutes;

    /*
        two types of delegation
        three types of slashing
    */

    struct SlasherParams {
        bool withSlasher;
        uint64 slaherIndex;
        bytes slasherParams;
    }

    struct DelegatorParams {
        uint64 delegatorIndex;
        bytes delegatorParams;
    }

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

        SlasherParams[3] memory slasherParams = [
            SlasherParams({withSlasher: false, slaherIndex: 0, slasherParams: new bytes(0)}),
            SlasherParams({
                withSlasher: true,
                slaherIndex: 0,
                slasherParams: new bytes(0) // Slasher
            }),
            SlasherParams({
                withSlasher: true,
                slaherIndex: 1,
                slasherParams: abi.encode(
                    IVetoSlasher.InitParams({
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
    }
}
