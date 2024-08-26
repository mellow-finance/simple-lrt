// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {IERC4626Vault} from "./IERC4626Vault.sol";

import {
    ERC4626Upgradeable,
    IERC4626
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import "./IMellowEigenLayerVaultStorage.sol";
import "../eigen/IDelegationManager.sol";
import "../eigen/IStrategyManager.sol";

interface IMellowEigenLayerVault is IERC4626Vault  {
    struct EigenLayerParam {
        IMellowEigenLayerVaultStorage.EigenLayerStorage storageParam;
        bytes delegationSignature;
        bytes32 salt;
        uint256 expiry;
    }

    struct InitParams {
        uint256 limit;
        address admin;
        EigenLayerParam eigenLayerParam;
        bool depositPause;
        bool withdrawalPause;
        bool depositWhitelist;
        string name;
        string symbol;
    }

    function initialize(InitParams memory initParams) external;

    event EigenLayerDeposited(address sender, uint256 vaultAmount);
    event Claimed(address account, address recipient, uint256 amount);
}
