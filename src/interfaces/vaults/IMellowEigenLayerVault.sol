// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {IERC4626Vault} from "./IERC4626Vault.sol";

import "@eigenlayer-interfaces/IDelegationManager.sol";

import "@eigenlayer-interfaces/IPausable.sol";
import "@eigenlayer-interfaces/IRewardsCoordinator.sol";
import "@eigenlayer-interfaces/IStrategyManager.sol";

import "./IMellowEigenLayerVaultStorage.sol";
import {
    ERC4626Upgradeable,
    IERC4626
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

interface IMellowEigenLayerVault is IERC4626Vault {
    struct EigenLayerParams {
        IStrategyManager strategyManager;
        IDelegationManager delegationManager;
        IRewardsCoordinator rewardsCoordinator;
        IStrategy strategy;
        address operator;
        uint256 claimWithdrawalsMax;
        bytes32 salt;
        ISignatureUtils.SignatureWithExpiry approverSignature;
    }

    struct InitParams {
        uint256 limit;
        address admin;
        address withdrawalQueue;
        bool depositPause;
        bool withdrawalPause;
        bool depositWhitelist;
        string name;
        string symbol;
        EigenLayerParams eigenLayerParams;
    }

    function initialize(InitParams memory initParams) external;
}
