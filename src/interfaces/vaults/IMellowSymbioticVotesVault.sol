// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {
    ERC20Upgradeable,
    ERC20VotesUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./IMellowSymbioticVault.sol";

interface IMellowSymbioticVotesVault {
    function initializeMellowSymbioticVotesVault(IMellowSymbioticVault.InitParams memory initParams)
        external;
}
