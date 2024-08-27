// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {IVaultConfigurator} from "@symbiotic/core/interfaces/IVaultConfigurator.sol";

import {IAccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../vaults/IMellowVaultCompat.sol";

interface IMellowLRT {
    function delegateCall(address to, bytes calldata data)
        external
        returns (bool success, bytes memory response);

    function underlyingTokens() external view returns (address[] memory underlyinigTokens_);

    function configurator() external view returns (IMellowLRTConfigurator);
}

interface IMellowLRTConfigurator {
    function validator() external view returns (IMellowLRTValidator);
}

interface IMellowLRTValidator {
    function hasPermission(address user, address contractAddress, bytes4 signature)
        external
        view
        returns (bool);
}

interface IDefaultBondStrategy {
    struct Data {
        address bond;
        uint256 ratioX96;
    }

    function vault() external view returns (address);

    function bondModule() external view returns (address);

    function setData(address token, Data[] memory data) external;

    function processAll() external;

    function tokenToData(address token) external view returns (bytes memory);
}

interface IDefaultBond {
    function asset() external view returns (address);
}

interface IDefaultBondModule {
    function withdraw(address bond, uint256 amount) external returns (uint256);
}

interface IMigrator {
    struct Parameters {
        address vault;
        address proxyAdmin;
        address proxyAdminOwner;
        address token;
        address bond;
        address defaultBondStrategy;
        IMellowSymbioticVault.InitParams initParams;
        IVaultConfigurator.InitParams symbioticVaultParams;
    }

    function singleton() external view returns (address);
    function symbioticVaultConfigurator() external view returns (address);
    function admin() external view returns (address);
    function migrationDelay() external view returns (uint256);
    function migrations() external view returns (uint256);

    function stageMigration(
        address defaultBondStrategy,
        address proxyAdmin,
        address proxyAdminOwner,
        IMellowSymbioticVault.InitParams memory initParams,
        IVaultConfigurator.InitParams memory symbioticVaultParams
    ) external returns (uint256 migrationIndex);

    function cancelMigration(uint256 migrationIndex) external;

    function migrate(uint256 migrationIndex) external;
}
