// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {
    ERC20Upgradeable,
    ERC20VotesUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";

interface IIdleVault {
    function initializeIdleVault(
        uint256 _limit,
        bool _depositPause,
        bool _withdrawalPause,
        bool _depositWhitelist,
        address _admin,
        string memory name,
        string memory symbol
    ) external;
}
