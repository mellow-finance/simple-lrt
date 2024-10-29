// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../scripts/mainnet/FactoryDeploy.sol";
import "../BaseTest.sol";
import "./AcceptanceFactoryRunner.sol";

import "../Constants.sol";

contract AcceptanceFactoryTest is AcceptanceFactoryRunner, BaseTest {
    function testAcceptanceFactoryOnlyDeployment() external {
        address symbioticVault = symbioticHelper.createNewSymbioticVault(
            SymbioticHelper.CreationParams({
                vaultOwner: makeAddr("symbioticVaultOwner"),
                vaultAdmin: makeAddr("symbioticVaultAdmin"),
                epochDuration: 7 days,
                asset: Constants.HOLESKY_WSTETH,
                isDepositLimit: false,
                depositLimit: 0
            })
        );

        FactoryDeploy.FactoryDeployParams memory deployParams = FactoryDeploy.FactoryDeployParams({
            factory: address(0),
            singletonName: keccak256("MellowSymbioticVault"),
            singletonVersion: 1,
            initParams: IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: makeAddr("mellowSymbioticVaultProxyAdmin"),
                limit: 1000 ether,
                symbioticCollateral: Constants.HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL,
                symbioticVault: symbioticVault,
                admin: makeAddr("mellowSymbioticVaultAdmin"),
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVaultCompat",
                symbol: "mstETH"
            }),
            setFarmRoleHoler: makeAddr("setFarmRoleHolder"),
            setLimitRoleHolder: makeAddr("setLimitRoleHolder"),
            pauseWithdrawalsRoleHolder: makeAddr("pauseWithdrawalsRoleHolder"),
            unpauseWithdrawalsRoleHolder: makeAddr("unpauseWithdrawalsRoleHolder"),
            pauseDepositsRoleHolder: makeAddr("pauseDepositsRoleHolder"),
            unpauseDepositsRoleHolder: makeAddr("unpauseDepositsRoleHolder"),
            setDepositWhitelistRoleHolder: makeAddr("setDepositWhitelistRoleHolder"),
            setDepositorWhitelistStatusRoleHolder: makeAddr("setDepositorWhitelistStatusRoleHolder")
        });
        IMellowSymbioticVault vault;
        (vault, deployParams) = FactoryDeploy.deploy(deployParams);

        runAcceptance(MellowSymbioticVault(address(vault)), deployParams);
    }

    function testAcceptanceFactoryWithDeposits() external {
        address symbioticVault = symbioticHelper.createNewSymbioticVault(
            SymbioticHelper.CreationParams({
                vaultOwner: makeAddr("symbioticVaultOwner"),
                vaultAdmin: makeAddr("symbioticVaultAdmin"),
                epochDuration: 7 days,
                asset: Constants.HOLESKY_WSTETH,
                isDepositLimit: false,
                depositLimit: 0
            })
        );

        FactoryDeploy.FactoryDeployParams memory deployParams = FactoryDeploy.FactoryDeployParams({
            factory: address(0),
            singletonName: keccak256("MellowSymbioticVault"),
            singletonVersion: 1,
            initParams: IMellowSymbioticVaultFactory.InitParams({
                proxyAdmin: makeAddr("mellowSymbioticVaultProxyAdmin"),
                limit: 1000 ether,
                symbioticCollateral: Constants.HOLESKY_WSTETH_SYMBIOTIC_COLLATERAL,
                symbioticVault: symbioticVault,
                admin: makeAddr("mellowSymbioticVaultAdmin"),
                depositPause: false,
                withdrawalPause: false,
                depositWhitelist: false,
                name: "MellowSymbioticVaultCompat",
                symbol: "mstETH"
            }),
            setFarmRoleHoler: makeAddr("setFarmRoleHolder"),
            setLimitRoleHolder: makeAddr("setLimitRoleHolder"),
            pauseWithdrawalsRoleHolder: makeAddr("pauseWithdrawalsRoleHolder"),
            unpauseWithdrawalsRoleHolder: makeAddr("unpauseWithdrawalsRoleHolder"),
            pauseDepositsRoleHolder: makeAddr("pauseDepositsRoleHolder"),
            unpauseDepositsRoleHolder: makeAddr("unpauseDepositsRoleHolder"),
            setDepositWhitelistRoleHolder: makeAddr("setDepositWhitelistRoleHolder"),
            setDepositorWhitelistStatusRoleHolder: makeAddr("setDepositorWhitelistStatusRoleHolder")
        });
        IMellowSymbioticVault vault;
        (vault, deployParams) = FactoryDeploy.deploy(deployParams);

        address user = makeAddr("user");
        vm.startPrank(user);
        deal(Constants.HOLESKY_WSTETH, user, 10 ether);
        IERC20(Constants.HOLESKY_WSTETH).approve(address(vault), 10 ether);
        vault.deposit(10 ether, user, user);
        deal(Constants.HOLESKY_WSTETH, address(vault), 10 ether);
        vm.stopPrank();

        runAcceptance(MellowSymbioticVault(address(vault)), deployParams);
    }
}
