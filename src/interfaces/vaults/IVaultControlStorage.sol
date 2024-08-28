// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title IVaultControlStorage
 * @notice Interface defining interaction with storage of IVaultControl.
 */
interface IVaultControlStorage {
    struct Storage {
        bool depositPause;
        bool withdrawalPause;
        uint256 limit;
        bool depositWhitelist;
        mapping(address account => bool status) isDepositorWhitelisted;
    }

    /**
     * @notice Returns value of `depositPause` state.
     */
    function depositPause() external view returns (bool);

    /**
     * @notice Returns value of `withdrawalPause` state.
     */
    function withdrawalPause() external view returns (bool);

    /**
     * @notice Returns value of the current `limit`.
     */
    function limit() external view returns (uint256);

    /**
     * @notice Returns value of `depositWhitelist` state.
     */
    function depositWhitelist() external view returns (bool);

    /**
     * @notice Checks whether `account` is whitelisted or not.
     * @param account Address of the account to check.
     */
    function isDepositorWhitelisted(address account) external view returns (bool);

    event LimitSet(uint256 limit, uint256 timestamp, address sender);
    event DepositPauseSet(bool paused, uint256 timestamp, address sender);
    event WithdrawalPauseSet(bool paused, uint256 timestamp, address sender);
    event DepositWhitelistSet(bool status, uint256 timestamp, address sender);
    event DepositorWhitelistStatusSet(
        address account, bool status, uint256 timestamp, address sender
    );
}
