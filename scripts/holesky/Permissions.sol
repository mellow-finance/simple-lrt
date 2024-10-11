// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

library Permissions {
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

    function roles() internal pure returns (bytes32[] memory roles_) {
        roles_ = new bytes32[](9);
        roles_[0] = SET_FARM_ROLE;
        roles_[1] = SET_LIMIT_ROLE;
        roles_[2] = PAUSE_WITHDRAWALS_ROLE;
        roles_[3] = UNPAUSE_WITHDRAWALS_ROLE;
        roles_[4] = PAUSE_DEPOSITS_ROLE;
        roles_[5] = UNPAUSE_DEPOSITS_ROLE;
        roles_[6] = SET_DEPOSIT_WHITELIST_ROLE;
        roles_[7] = SET_DEPOSITOR_WHITELIST_STATUS_ROLE;
        roles_[8] = DEFAULT_ADMIN_ROLE;
    }
}
