// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "forge-std/Base.sol";

import "../../scripts/mainnet/FactoryDeploy.sol";

contract AcceptanceFactoryRunner is CommonBase {
    function runAcceptance(
        MellowSymbioticVault vault,
        FactoryDeploy.FactoryDeployParams memory deployParams
    ) public view {
        runPermissionsTest(vault, deployParams);
        runValuesTest(vault, deployParams);
    }

    function runPermissionsTest(
        MellowSymbioticVault vault,
        FactoryDeploy.FactoryDeployParams memory deployParams
    ) public view {
        bytes32[9] memory roles = [
            FactoryDeploy.SET_FARM_ROLE,
            FactoryDeploy.SET_LIMIT_ROLE,
            FactoryDeploy.PAUSE_WITHDRAWALS_ROLE,
            FactoryDeploy.UNPAUSE_WITHDRAWALS_ROLE,
            FactoryDeploy.PAUSE_DEPOSITS_ROLE,
            FactoryDeploy.UNPAUSE_DEPOSITS_ROLE,
            FactoryDeploy.SET_DEPOSIT_WHITELIST_ROLE,
            FactoryDeploy.SET_DEPOSITOR_WHITELIST_STATUS_ROLE,
            FactoryDeploy.DEFAULT_ADMIN_ROLE
        ];

        address[9] memory expectedHolders = [
            deployParams.setFarmRoleHoler,
            deployParams.setLimitRoleHolder,
            deployParams.pauseWithdrawalsRoleHolder,
            deployParams.unpauseWithdrawalsRoleHolder,
            deployParams.pauseDepositsRoleHolder,
            deployParams.unpauseDepositsRoleHolder,
            deployParams.setDepositWhitelistRoleHolder,
            deployParams.setDepositorWhitelistStatusRoleHolder,
            deployParams.initParams.admin
        ];

        require(
            vault.getRoleMemberCount(FactoryDeploy.DEFAULT_ADMIN_ROLE) == 1,
            "Default admin should be set"
        );

        for (uint256 i = 0; i < roles.length; i++) {
            if (expectedHolders[i] == address(0)) {
                require(vault.getRoleMemberCount(roles[i]) == 0, "Role should not have any members");
            } else {
                require(
                    vault.getRoleMemberCount(roles[i]) == 1, "Role should have exactly one member"
                );
                require(
                    vault.getRoleMember(roles[i], 0) == expectedHolders[i],
                    "Role member should be the expected address"
                );
            }
        }
    }

    function runValuesTest(
        MellowSymbioticVault vault,
        FactoryDeploy.FactoryDeployParams memory deployParams
    ) public view {
        require(
            MellowSymbioticVaultFactory(deployParams.factory).isEntity(address(vault)),
            "Vault should be registered in the factory"
        );

        address immutableProxyAdmin =
            address(uint160(uint256(vm.load(address(vault), ERC1967Utils.ADMIN_SLOT))));
        require(
            ProxyAdmin(immutableProxyAdmin).owner() == deployParams.initParams.proxyAdmin,
            "Proxy admin should be set correctly"
        );
        require(deployParams.initParams.proxyAdmin != address(0), "Proxy admin should be set");

        require(vault.limit() == deployParams.initParams.limit, "Limit should be set correctly");

        require(
            address(vault.symbioticCollateral()) == deployParams.initParams.symbioticCollateral,
            "Symbiotic collateral should be set correctly"
        );

        require(
            address(vault.symbioticVault()) == deployParams.initParams.symbioticVault,
            "Symbiotic vault should be set correctly"
        );

        require(
            vault.depositPause() == deployParams.initParams.depositPause,
            "Deposit pause should be set correctly"
        );

        require(
            vault.withdrawalPause() == deployParams.initParams.withdrawalPause,
            "Withdrawal pause should be set correctly"
        );

        require(
            vault.depositWhitelist() == deployParams.initParams.depositWhitelist,
            "Deposit whitelist should be set correctly"
        );

        require(
            keccak256(abi.encodePacked(vault.name()))
                == keccak256(abi.encodePacked(deployParams.initParams.name)),
            "Name should be set correctly"
        );

        require(
            keccak256(abi.encodePacked(vault.symbol()))
                == keccak256(abi.encodePacked(deployParams.initParams.symbol)),
            "Symbol should be set correctly"
        );
    }
}
