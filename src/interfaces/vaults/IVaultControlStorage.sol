// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

interface IVaultControlStorage {
    struct Storage {
        bool depositPause;
        bool withdrawalPause;
        uint256 limit;
        bool depositWhitelist;
        mapping(address account => bool status) isDepositorWhitelisted;
    }
}
