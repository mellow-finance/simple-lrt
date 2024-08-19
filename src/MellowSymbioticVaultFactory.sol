// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/vaults/IMellowSymbioticVaultFactory.sol";

import {MellowSymbioticVault} from "./MellowSymbioticVault.sol";
import {SymbioticWithdrawalQueue} from "./SymbioticWithdrawalQueue.sol";

contract MellowSymbioticVaultFactory is IMellowSymbioticVaultFactory {
    address public immutable singleton;

    mapping(address => bool) private _isEntity;
    address[] private _entities;

    constructor(address singleton_) {
        singleton = singleton_;
    }

    function create(address _proxyAdmin, IMellowSymbioticVault.InitParams memory initParams)
        external
        returns (MellowSymbioticVault vault)
    {
        vault = MellowSymbioticVault(
            address(new TransparentUpgradeableProxy(singleton, _proxyAdmin, ""))
        );
        initParams.withdrawalQueue =
            address(new SymbioticWithdrawalQueue(address(vault), initParams.symbioticVault));
        vault.initialize(initParams);
        _isEntity[address(vault)] = true;
        _entities.push(address(vault));
        emit EntityCreated(address(vault), block.timestamp);
    }

    function entities() external view returns (address[] memory) {
        return _entities;
    }

    function entitiesLength() external view returns (uint256) {
        return _entities.length;
    }

    function isEntity_(address entity) external view returns (bool) {
        return _isEntity[entity];
    }

    function entityAt(uint256 index) external view returns (address) {
        return _entities[index];
    }
}
