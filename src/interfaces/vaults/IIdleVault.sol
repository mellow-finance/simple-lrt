// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {
    ERC20Upgradeable,
    ERC20VotesUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";

interface IIdleVault {
    struct InitParams {
        uint256 limit;
        bool depositPause;
        bool withdrawalPause;
        bool depositWhitelist;
        address admin;
        string name;
        string symbol;
    }

    function initializeIdleVault(InitParams memory initParams) external;

    event IdleVaultInitialized(InitParams initParams, uint256 timestamp);
}
