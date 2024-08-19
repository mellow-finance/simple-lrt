// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {IMellowSymbioticVault} from "./IMellowSymbioticVault.sol";

interface IMellowSymbioticVaultFactory {
    struct InitParams {
        address proxyAdmin;
        uint256 limit;
        address symbioticVault;
        address admin;
        bool depositPause;
        bool withdrawalPause;
        bool depositWhitelist;
        string name;
        string symbol;
    }

    event EntityCreated(address indexed vault, uint256 timestamp);
}
