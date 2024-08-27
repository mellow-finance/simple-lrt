// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {IMellowSymbioticVault} from "./IMellowSymbioticVault.sol";

import {IWithdrawalQueue} from "../utils/IWithdrawalQueue.sol";

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

    function singleton() external view returns (address);

    function create(InitParams memory initParams)
        external
        returns (IMellowSymbioticVault vault, IWithdrawalQueue withdrawalQueue);

    function entities() external view returns (address[] memory);

    function entitiesLength() external view returns (uint256);

    function isEntity(address entity) external view returns (bool);

    function entityAt(uint256 index) external view returns (address);

    event EntityCreated(address indexed vault, uint256 timestamp);
}
