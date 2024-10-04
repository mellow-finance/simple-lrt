// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;



import "forge-std/Script.sol";
import "./FactoryDeploy.sol";

import {DelegatorFactory} from "@symbiotic/core/contracts/DelegatorFactory.sol";
import {NetworkRegistry} from "@symbiotic/core/contracts/NetworkRegistry.sol";
import {OperatorRegistry} from "@symbiotic/core/contracts/OperatorRegistry.sol";
import {SlasherFactory} from "@symbiotic/core/contracts/SlasherFactory.sol";
import {VaultConfigurator} from "@symbiotic/core/contracts/VaultConfigurator.sol";
import {VaultFactory} from "@symbiotic/core/contracts/VaultFactory.sol";
import {
    FullRestakeDelegator,
    IBaseDelegator,
    IFullRestakeDelegator
} from "@symbiotic/core/contracts/delegator/FullRestakeDelegator.sol";

import {NetworkMiddlewareService} from
    "@symbiotic/core/contracts/service/NetworkMiddlewareService.sol";
import {Slasher} from "@symbiotic/core/contracts/slasher/Slasher.sol";
import {Vault} from "@symbiotic/core/contracts/vault/Vault.sol";

import {IVaultConfigurator} from "@symbiotic/core/interfaces/IVaultConfigurator.sol";
import {IVault} from "@symbiotic/core/interfaces/vault/IVault.sol";


contract Deploy is Script, FactoryDeploy {
    
    address public constant HOLESKY_DEPLOYER = 0x7777775b9E6cE9fbe39568E485f5E20D1b0e04EE;

    address public constant HOLESKY_WSTETH = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D;
    address public constant HOLESKY_WSTETH_DEFAULT_COLLATERAL = 0x23E98253F372Ee29910e22986fe75Bb287b011fC;
    
    uint256 public constant HOLESKY_LIMIT = 10 ether;
    uint48 public constant HOLESKY_EPOCH_DURATION = 1 hours;
    

    function createSymbioticVault() internal returns (address symbioticVault) {
        IFullRestakeDelegator.InitParams memory initParams = IFullRestakeDelegator.InitParams({
            baseParams: IBaseDelegator.BaseParams({
                defaultAdminRoleHolder: HOLESKY_DEPLOYER,
                hook: address(0),
                hookSetRoleHolder: HOLESKY_DEPLOYER
            }),
            networkLimitSetRoleHolders: new address[](0),
            operatorNetworkLimitSetRoleHolders: new address[](0)
        });
        (symbioticVault,,) = IVaultConfigurator(
            0x382e9c6fF81F07A566a8B0A3622dc85c47a891Df
        ).create(
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
                delegatorIndex: 0,
                delegatorParams: abi.encode(initParams),
                withSlasher: false,
                slasherIndex: 0,
                slasherParams: ""
            })
        );
    }


    function run() external {
        vm.startBroadcast(uint256(bytes32(vm.envBytes("HOLESKY_DEPLOYER"))));
        
        address symbioticVault = createSymbioticVault();
        
        (IMellowSymbioticVault mellowVaut, FactoryDeploy.FactoryDeployParams memory params) = FactoryDeploy.deploy(
            HOLESKY_DEPLOYER,
            FactoryDeploy.FactoryDeployParams({
                factory: address(0),
                singletonName: bytes32("holesky-test-deployment"),
                singletonVersion: 1,
                setFarmRoleHoler: HOLESKY_DEPLOYER,
                setLimitRoleHolder: HOLESKY_DEPLOYER,
                pauseWithdrawalsRoleHolder: HOLESKY_DEPLOYER,
                unpauseWithdrawalsRoleHolder: HOLESKY_DEPLOYER,
                pauseDepositsRoleHolder: HOLESKY_DEPLOYER,
                unpauseDepositsRoleHolder: HOLESKY_DEPLOYER,
                setDepositWhitelistRoleHolder: HOLESKY_DEPLOYER,
                setDepositorWhitelistStatusRoleHolder: HOLESKY_DEPLOYER,
                initParams: IMellowSymbioticVaultFactory.InitParams({
                    proxyAdmin: HOLESKY_DEPLOYER,
                    limit: HOLESKY_LIMIT,
                    symbioticCollateral: HOLESKY_WSTETH_DEFAULT_COLLATERAL,
                    symbioticVault: symbioticVault,
                    admin: HOLESKY_DEPLOYER,
                    depositPause: false,
                    withdrawalPause: false,
                    depositWhitelist: false,
                    name: "Mellow Protocol: test-test-test",
                    symbol: "MEL:SLRT"
                })
            })
        );

        vm.stopBroadcast();

        console2.log("MellowSymbioticVault:", address(mellowVaut));
        console2.log("MellowSymbioticVaultFactory:", params.factory);
        console2.log(
            "SymbioticVault:", symbioticVault
        );
    }
}
