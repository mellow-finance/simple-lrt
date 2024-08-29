// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/vaults/IMellowSymbioticVaultFactory.sol";

import {SymbioticWithdrawalQueue} from "./SymbioticWithdrawalQueue.sol";

contract MellowSymbioticVaultFactory is IMellowSymbioticVaultFactory {
    mapping(address => bool) private _isEntity;
    address[] private _entities;

    /// @inheritdoc IMellowSymbioticVaultFactory
    address public immutable singleton;

    constructor(address singleton_) {
        singleton = singleton_;
    }

    /// @inheritdoc IMellowSymbioticVaultFactory
    function create(InitParams memory initParams)
        external
        returns (IMellowSymbioticVault vault, IWithdrawalQueue withdrawalQueue)
    {
        vault = IMellowSymbioticVault(
            address(new TransparentUpgradeableProxy(singleton, initParams.proxyAdmin, ""))
        );
        withdrawalQueue = new SymbioticWithdrawalQueue(address(vault), initParams.symbioticVault);
        vault.initialize(
            IMellowSymbioticVault.InitParams({
                limit: initParams.limit,
                symbioticCollateral: initParams.symbioticCollateral,
                symbioticVault: initParams.symbioticVault,
                withdrawalQueue: address(withdrawalQueue),
                admin: initParams.admin,
                depositPause: initParams.depositPause,
                withdrawalPause: initParams.withdrawalPause,
                depositWhitelist: initParams.depositWhitelist,
                name: initParams.name,
                symbol: initParams.symbol
            })
        );
        _isEntity[address(vault)] = true;
        _entities.push(address(vault));
        emit EntityCreated(address(vault), block.timestamp);
    }

    /// @inheritdoc IMellowSymbioticVaultFactory
    function entities() external view returns (address[] memory) {
        return _entities;
    }

    /// @inheritdoc IMellowSymbioticVaultFactory
    function entitiesLength() external view returns (uint256) {
        return _entities.length;
    }

    /// @inheritdoc IMellowSymbioticVaultFactory
    function isEntity(address entity) external view returns (bool) {
        return _isEntity[entity];
    }

    /// @inheritdoc IMellowSymbioticVaultFactory
    function entityAt(uint256 index) external view returns (address) {
        return _entities[index];
    }
}
