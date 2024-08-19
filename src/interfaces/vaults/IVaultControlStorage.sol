// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IVaultControlStorage {
    struct Storage {
        bool depositPause;
        bool withdrawalPause;
        uint256 limit;
        bool depositWhitelist;
        mapping(address account => bool status) isDepositorWhitelisted;
    }

    event LimitSet(uint256 limit, uint256 timestamp, address sender);
    event DepositPauseSet(bool paused, uint256 timestamp, address sender);
    event WithdrawalPauseSet(bool paused, uint256 timestamp, address sender);
    event DepositWhitelistSet(bool status, uint256 timestamp, address sender);
    event DepositorWhitelistStatusSet(
        address account, bool status, uint256 timestamp, address sender
    );
}
