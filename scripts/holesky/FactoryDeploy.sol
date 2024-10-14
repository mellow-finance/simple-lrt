// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/MellowSymbioticVault.sol";
import "../../src/MellowSymbioticVaultFactory.sol";

import "../../src/Migrator.sol";
import "../../src/VaultControl.sol";

import "./Permissions.sol";

contract FactoryDeploy {
    struct FactoryDeployParams {
        address deployer;
        address factory;
        bytes32 singletonName;
        uint256 singletonVersion;
        address setFarmRoleHoler;
        address setLimitRoleHolder;
        address pauseWithdrawalsRoleHolder;
        address unpauseWithdrawalsRoleHolder;
        address pauseDepositsRoleHolder;
        address unpauseDepositsRoleHolder;
        address setDepositWhitelistRoleHolder;
        address setDepositorWhitelistStatusRoleHolder;
        IMellowSymbioticVaultFactory.InitParams initParams;
    }

    function commonDeploy(FactoryDeployParams memory $)
        public
        returns (FactoryDeployParams memory)
    {
        if ($.factory == address(0)) {
            require($.singletonName != bytes32(0), "FactoryDeploy: singletonName is required");
            $.factory = address(
                new MellowSymbioticVaultFactory(
                    address(new MellowSymbioticVault($.singletonName, $.singletonVersion))
                )
            );
        }
        return $;
    }

    function _grantRole(address _vault, bytes32 _role, address _account) private {
        if (_account == address(0)) {
            return;
        }
        VaultControl(_vault).grantRole(_role, _account);
    }

    function deploy(FactoryDeployParams memory $)
        public
        returns (IMellowSymbioticVault, FactoryDeployParams memory)
    {
        $ = commonDeploy($);
        address admin = $.initParams.admin;
        $.initParams.admin = $.deployer;

        (IMellowSymbioticVault vault,) = MellowSymbioticVaultFactory($.factory).create($.initParams);
        _grantRole(address(vault), Permissions.SET_FARM_ROLE, $.setFarmRoleHoler);
        _grantRole(address(vault), Permissions.SET_LIMIT_ROLE, $.setLimitRoleHolder);
        _grantRole(address(vault), Permissions.PAUSE_WITHDRAWALS_ROLE, $.pauseWithdrawalsRoleHolder);
        _grantRole(
            address(vault), Permissions.UNPAUSE_WITHDRAWALS_ROLE, $.unpauseWithdrawalsRoleHolder
        );
        _grantRole(address(vault), Permissions.PAUSE_DEPOSITS_ROLE, $.pauseDepositsRoleHolder);
        _grantRole(address(vault), Permissions.UNPAUSE_DEPOSITS_ROLE, $.unpauseDepositsRoleHolder);
        _grantRole(
            address(vault), Permissions.SET_DEPOSIT_WHITELIST_ROLE, $.setDepositWhitelistRoleHolder
        );
        _grantRole(
            address(vault),
            Permissions.SET_DEPOSITOR_WHITELIST_STATUS_ROLE,
            $.setDepositorWhitelistStatusRoleHolder
        );
        _grantRole(address(vault), Permissions.DEFAULT_ADMIN_ROLE, admin);
        VaultControl(address(vault)).renounceRole(
            Permissions.DEFAULT_ADMIN_ROLE, $.initParams.admin
        );
        $.initParams.admin = admin;
        return (vault, $);
    }
}
