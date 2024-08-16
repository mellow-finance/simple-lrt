// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {ERC20Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC4626Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {
    Context, ERC20, IERC20, IERC20Metadata
} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./IMellowSymbioticVault.sol";

interface IEthVaultCompat {
    function initializeEthVaultCompat(IMellowSymbioticVault.InitParams memory initParams)
        external;
}
