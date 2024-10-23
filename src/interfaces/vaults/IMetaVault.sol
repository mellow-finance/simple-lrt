// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ERC20Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC4626Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {Context, ERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IBaseDepositStrategy} from "../strategies/IBaseDepositStrategy.sol";

import {IBaseRebalanceStrategy} from "../strategies/IBaseRebalanceStrategy.sol";
import {IBaseWithdrawalStrategy} from "../strategies/IBaseWithdrawalStrategy.sol";

import "./IERC4626Vault.sol";
import "./IQueuedVault.sol";

interface IMetaVault is IERC4626Vault {
    struct InitParams {
        address depositStrategy;
        address withdrawalStrategy;
        address rebalanceStrategy;
        address idleVault;
        address asset;
        uint256 limit;
        address admin;
        bool depositPause;
        bool withdrawalPause;
        bool depositWhitelist;
        string name;
        string symbol;
    }
}
