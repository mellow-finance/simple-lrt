// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./Imports.sol";

contract MockVaultControlStorage is VaultControlStorage {
    constructor() VaultControlStorage("mock", 1) {}

    struct Slot {
        bytes32 value;
    }

    function slotStorageRef() external view returns (bytes32) {
        Slot storage s;
        assembly {
            s.slot := 0
        }
        return s.value;
    }

    function initializeVaultControlStorage(
        uint256 _limit,
        bool _depositPause,
        bool _withdrawalPause,
        bool _depositWhitelist
    ) external initializer {
        __initializeVaultControlStorage(_limit, _depositPause, _withdrawalPause, _depositWhitelist);
    }

    function setLimit(uint256 _limit) external {
        _setLimit(_limit);
    }

    function setDepositPause(bool _paused) external {
        _setDepositPause(_paused);
    }

    function setWithdrawalPause(bool _paused) external {
        _setWithdrawalPause(_paused);
    }

    function setDepositWhitelist(bool _status) external {
        _setDepositWhitelist(_status);
    }

    function setDepositorWhitelistStatus(address account, bool status) external {
        _setDepositorWhitelistStatus(account, status);
    }

    function test() external pure {}
}

contract Unit is Test {
    function test() external {
        MockVaultControlStorage c = new MockVaultControlStorage();
        c.initializeVaultControlStorage(123, false, false, false);
        assertEq(c.limit(), 123);
        assertEq(c.depositPause(), false);
        assertEq(c.withdrawalPause(), false);
        assertEq(c.depositWhitelist(), false);
    }
}
