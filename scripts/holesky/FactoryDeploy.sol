// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../../src/MellowSymbioticVault.sol";
import "../../src/MellowSymbioticVaultFactory.sol";

import "../../src/Migrator.sol";
import "../../src/VaultControl.sol";

contract FactoryDeploy {
    bytes32 public constant SET_FARM_ROLE = keccak256("SET_FARM_ROLE");
    bytes32 public constant SET_LIMIT_ROLE = keccak256("SET_LIMIT_ROLE");
    bytes32 public constant PAUSE_WITHDRAWALS_ROLE = keccak256("PAUSE_WITHDRAWALS_ROLE");
    bytes32 public constant UNPAUSE_WITHDRAWALS_ROLE = keccak256("UNPAUSE_WITHDRAWALS_ROLE");
    bytes32 public constant PAUSE_DEPOSITS_ROLE = keccak256("PAUSE_DEPOSITS_ROLE");
    bytes32 public constant UNPAUSE_DEPOSITS_ROLE = keccak256("UNPAUSE_DEPOSITS_ROLE");
    bytes32 public constant SET_DEPOSIT_WHITELIST_ROLE = keccak256("SET_DEPOSIT_WHITELIST_ROLE");
    bytes32 public constant SET_DEPOSITOR_WHITELIST_STATUS_ROLE =
        keccak256("SET_DEPOSITOR_WHITELIST_STATUS_ROLE");

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    struct FactoryDeployParams {
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

    function commonDeploy(FactoryDeployParams memory $) public returns (FactoryDeployParams memory) {
        if ($.factory == address(0)) {
            require(
                $.singletonName != bytes32(0),
                "FactoryDeploy: singletonName is required"
            );
            $.factory = address(new MellowSymbioticVaultFactory(
                address(new MellowSymbioticVault(
                    $.singletonName,
                    $.singletonVersion
                ))
            ));               
        }
        return $;
    }

    function _grantRole(address _vault, bytes32 _role, address _account) private {
        if (_account == address(0)) return;
        VaultControl(_vault).grantRole(_role, _account);
    }

    function deploy(address deployer, FactoryDeployParams memory $) public returns (IMellowSymbioticVault , FactoryDeployParams memory) {
        $ = commonDeploy($);
        address admin = $.initParams.admin;
        $.initParams.admin = deployer;
        
        (IMellowSymbioticVault vault, ) = MellowSymbioticVaultFactory($.factory).create($.initParams);
        _grantRole(address(vault), SET_FARM_ROLE, $.setFarmRoleHoler);
        _grantRole(address(vault), SET_LIMIT_ROLE, $.setLimitRoleHolder);
        _grantRole(address(vault), PAUSE_WITHDRAWALS_ROLE, $.pauseWithdrawalsRoleHolder);
        _grantRole(address(vault), UNPAUSE_WITHDRAWALS_ROLE, $.unpauseWithdrawalsRoleHolder);
        _grantRole(address(vault), PAUSE_DEPOSITS_ROLE, $.pauseDepositsRoleHolder);
        _grantRole(address(vault), UNPAUSE_DEPOSITS_ROLE, $.unpauseDepositsRoleHolder);
        _grantRole(address(vault), SET_DEPOSIT_WHITELIST_ROLE, $.setDepositWhitelistRoleHolder);
        _grantRole(address(vault), SET_DEPOSITOR_WHITELIST_STATUS_ROLE, $.setDepositorWhitelistStatusRoleHolder);
        _grantRole(address(vault), DEFAULT_ADMIN_ROLE, admin);
        VaultControl(address(vault)).renounceRole(DEFAULT_ADMIN_ROLE, $.initParams.admin);
        $.initParams.admin = admin;
        return (vault, $);
    }
}
