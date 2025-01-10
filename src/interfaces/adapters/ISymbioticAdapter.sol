// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ISymbioticWithdrawalQueue} from "../queues/ISymbioticWithdrawalQueue.sol";
import {IProtocolAdapter} from "./IProtocolAdapter.sol";
import {IERC20, IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRegistry} from "@symbiotic/core/interfaces/common/IRegistry.sol";
import {IVault as ISymbioticVault} from "@symbiotic/core/interfaces/vault/IVault.sol";
import {IStakerRewards} from "@symbiotic/rewards/interfaces/stakerRewards/IStakerRewards.sol";

/**
 * @title ISymbioticAdapter
 * @notice Interface for a symbiotic adapter that extends `IProtocolAdapter` for managing symbiotic vaults.
 * @dev Adds functionality for interacting with withdrawal queues and a registry-based vault factory.
 */
interface ISymbioticAdapter is IProtocolAdapter {
    /**
     * @notice Retrieves the withdrawal queue associated with a specific symbiotic vault.
     * @param symbioticVault The address of the symbiotic vault.
     * @return withdrawalQueue The address of the withdrawal queue linked to the specified symbiotic vault.
     */
    function withdrawalQueues(address symbioticVault)
        external
        view
        returns (address withdrawalQueue);

    /**
     * @notice Returns the address of the vault factory used for managing symbiotic vaults.
     * returns the address of the `IRegistry` contract that acts as the vault factory.
     */
    function vaultFactory() external view returns (IRegistry);
}
