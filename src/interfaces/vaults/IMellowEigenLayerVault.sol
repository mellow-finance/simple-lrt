// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {IERC4626Vault} from "./IERC4626Vault.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {
    ERC4626Upgradeable,
    IERC4626
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

import "../eigen/IStrategyManager.sol";
import "../eigen/IDelegationManager.sol";

interface IMellowEigenLayerVault is IERC4626Vault {
    struct DelegationParam {
        address strategyManager;
        address delegationManager;
        address strategy;
        address operator;
        bytes delegationSignature;
        bytes32 salt;
        uint256 expiry;
    }
    struct InitParams {
        uint256 limit;
        address admin;
        DelegationParam delegationParam;
        bool depositPause;
        bool withdrawalPause;
        bool depositWhitelist;
        string name;
        string symbol;
    }

    function initialize(InitParams memory initParams) external;
}
