// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./IDelegationManager.sol";
import "./IStrategy.sol";

interface IStrategyManager {
    function initialize(
        address initialOwner,
        address initialStrategyWhitelister,
        uint256 initialPausedStatus
    ) external;

    function depositIntoStrategy(IStrategy strategy, IERC20 token, uint256 amount)
        external
        returns (uint256 depositShares);

    function depositIntoStrategyWithSignature(
        IStrategy strategy,
        IERC20 token,
        uint256 amount,
        address staker,
        uint256 expiry,
        bytes memory signature
    ) external returns (uint256 depositShares);

    function burnShares(IStrategy strategy) external;

    function setStrategyWhitelister(address newStrategyWhitelister) external;

    function addStrategiesToDepositWhitelist(IStrategy[] calldata strategiesToWhitelist) external;

    function removeStrategiesFromDepositWhitelist(
        IStrategy[] calldata strategiesToRemoveFromWhitelist
    ) external;

    function strategyIsWhitelistedForDeposit(IStrategy strategy) external view returns (bool);

    function getDeposits(address staker)
        external
        view
        returns (IStrategy[] memory, uint256[] memory);

    function getStakerStrategyList(address staker) external view returns (IStrategy[] memory);

    function stakerStrategyListLength(address staker) external view returns (uint256);

    function stakerDepositShares(address user, IStrategy strategy)
        external
        view
        returns (uint256 shares);

    function delegation() external view returns (IDelegationManager);

    function strategyWhitelister() external view returns (address);

    function getBurnableShares(IStrategy strategy) external view returns (uint256);

    function getStrategiesWithBurnableShares()
        external
        view
        returns (address[] memory, uint256[] memory);

    function calculateStrategyDepositDigestHash(
        address staker,
        IStrategy strategy,
        IERC20 token,
        uint256 amount,
        uint256 nonce,
        uint256 expiry
    ) external view returns (bytes32);
}
