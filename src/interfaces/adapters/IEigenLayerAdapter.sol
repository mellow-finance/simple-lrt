// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IIsolatedEigenLayerVault} from "./IIsolatedEigenLayerVault.sol";
import {IIsolatedEigenLayerVaultFactory} from "./IIsolatedEigenLayerVaultFactory.sol";
import {IProtocolAdapter} from "./IProtocolAdapter.sol";
import {IDelegationManager} from "@eigenlayer-interfaces/IDelegationManager.sol";
import {IPausable} from "@eigenlayer-interfaces/IPausable.sol";
import {IRewardsCoordinator} from "@eigenlayer-interfaces/IRewardsCoordinator.sol";
import {IStrategy, IStrategyManager} from "@eigenlayer-interfaces/IStrategyManager.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title IEigenLayerAdapter
 * @notice Interface for an adapter that integrates with the EigenLayer protocol.
 * @dev Provides methods for interacting with EigenLayer-specific components such as the factory,
 *      rewards coordinator, strategy manager, delegation manager, and withdrawal claiming.
 */
interface IEigenLayerAdapter is IProtocolAdapter {
    /**
     * @notice Returns the factory responsible for creating isolated EigenLayer vaults.
     * returns the address of the `IIsolatedEigenLayerVaultFactory` contract.
     */
    function factory() external view returns (IIsolatedEigenLayerVaultFactory);

    /**
     * @notice Returns the rewards coordinator used for managing rewards in EigenLayer.
     * returns the address of the `IRewardsCoordinator` contract.
     */
    function rewardsCoordinator() external view returns (IRewardsCoordinator);

    /**
     * @notice Returns the strategy manager used for handling strategies in EigenLayer.
     * returns the address of the `IStrategyManager` contract.
     */
    function strategyManager() external view returns (IStrategyManager);

    /**
     * @notice Returns the delegation manager responsible for managing delegations in EigenLayer.
     * returns the address of the `IDelegationManager` contract.
     */
    function delegationManager() external view returns (IDelegationManager);

    /**
     * @notice Claims a withdrawal from an isolated EigenLayer vault.
     * @dev Executes the claim process for an EigenLayer withdrawal using the provided data.
     * @param isolatedVault The address of the isolated vault from which the withdrawal is being claimed.
     * @param data A struct containing the withdrawal details, including the strategies, shares, and other relevant information.
     * @return assets The amount of assets successfully claimed from the withdrawal.
     */
    function claimWithdrawal(address isolatedVault, IDelegationManager.Withdrawal calldata data)
        external
        returns (uint256 assets);
}
