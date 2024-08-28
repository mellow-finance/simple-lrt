// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {IMellowSymbioticVault} from "./IMellowSymbioticVault.sol";

import {IWithdrawalQueue} from "../utils/IWithdrawalQueue.sol";

/**
 * @title IMellowSymbioticVaultFactory
 * @notice Interface of singleton factory to deploy new Vaults.
 */
interface IMellowSymbioticVaultFactory {
    struct InitParams {
        address proxyAdmin;
        uint256 limit;
        address symbioticVault;
        address admin;
        bool depositPause;
        bool withdrawalPause;
        bool depositWhitelist;
        string name;
        string symbol;
    }

    /// @notice Returns address of singleton factory.
    function singleton() external view returns (address);

    /**
     * @notice Creates a new MellowSymbioticVault with given `initParams`.
     * @param initParams Initial parameters for a new Vault.
     * @return vault Address of a new deployed Vault.
     * @return withdrawalQueue Address of a new deployed WithdrawalQueue.
     *
     * @custom:effects
     * - Emits EntityCreated event
     */
    function create(InitParams memory initParams)
        external
        returns (IMellowSymbioticVault vault, IWithdrawalQueue withdrawalQueue);

    /// @notice Returns addresses of call deployed vaults.
    function entities() external view returns (address[] memory);

    /// @notice Returns count of deployed vaults.
    function entitiesLength() external view returns (uint256);

    /**
     * @notice Checks whether `entity` is deployd vault by the Factory.
     * @param entity Address to check.
     */
    function isEntity(address entity) external view returns (bool);

    /**
     * @notice Returns address of the Vault deployed at `index`.
     * @param index Index of entity.
     */
    function entityAt(uint256 index) external view returns (address);

    event EntityCreated(address indexed vault, uint256 timestamp);
}
