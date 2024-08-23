// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/vaults/IMellowSymbioticVaultFactory.sol";

import {IWithdrawalQueue, SymbioticWithdrawalQueue} from "./SymbioticWithdrawalQueue.sol";

contract MellowSymbioticVaultFactory is IMellowSymbioticVaultFactory {
    address public immutable singleton;

    mapping(address => bool) private _isEntity;
    address[] private _entities;

    constructor(address singleton_) {
        singleton = singleton_;
    }

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

    function entities() external view returns (address[] memory) {
        return _entities;
    }

    function entitiesLength() external view returns (uint256) {
        return _entities.length;
    }

    function isEntity(address entity) external view returns (bool) {
        return _isEntity[entity];
    }

    function entityAt(uint256 index) external view returns (address) {
        return _entities[index];
    }
}
