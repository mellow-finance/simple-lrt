// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../Imports.sol";

contract MockVaultControlStorage is VaultControlStorage {
    constructor(bytes32 name, uint256 version) VaultControlStorage(name, version) {}

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
    function testConstructor() external {
        MockVaultControlStorage c = new MockVaultControlStorage(keccak256("name"), 1);
        assertNotEq(address(c), address(0));
    }

    function testInitializeVaultControlStorage() external {
        uint256 limit = 100 ether;
        bytes32[5] memory topics = [
            keccak256("LimitSet(uint256,uint256,address)"),
            keccak256("DepositPauseSet(bool,uint256,address)"),
            keccak256("WithdrawalPauseSet(bool,uint256,address)"),
            keccak256("DepositWhitelistSet(bool,uint256,address)"),
            keccak256("Initialized(uint64)")
        ];
        {
            MockVaultControlStorage c = new MockVaultControlStorage(keccak256("mock"), 1);
            vm.recordLogs();
            c.initializeVaultControlStorage(limit, false, false, false);
            Vm.Log[] memory logs = vm.getRecordedLogs();
            assertEq(logs.length, 5);
            for (uint256 i = 0; i < 5; i++) {
                assertEq(logs[i].emitter, address(c));
                assertEq(logs[i].topics[0], topics[i]);
            }
            assertEq(c.limit(), limit);
            assertEq(c.depositPause(), false);
            assertEq(c.withdrawalPause(), false);
            assertEq(c.depositWhitelist(), false);
        }
        {
            MockVaultControlStorage c = new MockVaultControlStorage(keccak256("mock"), 1);
            vm.recordLogs();
            c.initializeVaultControlStorage(limit, true, true, true);
            Vm.Log[] memory logs = vm.getRecordedLogs();
            assertEq(logs.length, 5);
            for (uint256 i = 0; i < 5; i++) {
                assertEq(logs[i].emitter, address(c));
                assertEq(logs[i].topics[0], topics[i]);
            }
            assertEq(c.limit(), limit);
            assertEq(c.depositPause(), true);
            assertEq(c.withdrawalPause(), true);
            assertEq(c.depositWhitelist(), true);
        }
    }

    function testSetLimit() external {
        MockVaultControlStorage c = new MockVaultControlStorage(keccak256("mock"), 1);
        uint256 limit = 100 ether;
        c.setLimit(limit);
        assertEq(c.limit(), limit);
    }

    function testSetDepositPause() external {
        MockVaultControlStorage c = new MockVaultControlStorage(keccak256("mock"), 1);
        c.setDepositPause(true);
        assertEq(c.depositPause(), true);
        c.setDepositPause(false);
        assertEq(c.depositPause(), false);
    }

    function testSetWithdrawalPause() external {
        MockVaultControlStorage c = new MockVaultControlStorage(keccak256("mock"), 1);
        c.setWithdrawalPause(true);
        assertEq(c.withdrawalPause(), true);
        c.setWithdrawalPause(false);
        assertEq(c.withdrawalPause(), false);
    }

    function testSetDepositWhitelist() external {
        MockVaultControlStorage c = new MockVaultControlStorage(keccak256("mock"), 1);
        c.setDepositWhitelist(true);
        assertEq(c.depositWhitelist(), true);
        c.setDepositWhitelist(false);
        assertEq(c.depositWhitelist(), false);
    }

    function testSetDepositorWhitelistStatus() external {
        MockVaultControlStorage c = new MockVaultControlStorage(keccak256("mock"), 1);
        address account = address(0x123);
        c.setDepositorWhitelistStatus(account, true);
        assertEq(c.isDepositorWhitelisted(account), true);
        c.setDepositorWhitelistStatus(account, false);
        assertEq(c.isDepositorWhitelisted(account), false);
    }
}
