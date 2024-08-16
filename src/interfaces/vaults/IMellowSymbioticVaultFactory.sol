// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {IMellowSymbioticVault} from "./IMellowSymbioticVault.sol";

interface IMellowSymbioticVaultFactory {
    event EntityCreated(address indexed entity, uint256 timestamp);
}
