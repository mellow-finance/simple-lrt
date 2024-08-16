// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {MellowSymbioticVotesVault} from "./MellowSymbioticVotesVault.sol";

contract MellowSymbioticVotesVaultFactory {
    address public immutable singleton;

    mapping(address => bool) private _isEntity;
    address[] private _entities;

    constructor(address singleton_) {
        singleton = singleton_;
    }

    function create(
        address _proxyAdmin,
        address _symbioticVault,
        address _withdrawalQueue,
        uint256 _limit,
        bool _depositPause,
        bool _withdrawalPause,
        bool _depositWhitelist,
        address _admin,
        string memory _name,
        string memory _symbol
    ) external returns (MellowSymbioticVotesVault vault) {
        vault = MellowSymbioticVotesVault(
            address(new TransparentUpgradeableProxy(singleton, _proxyAdmin, ""))
        );
        vault.initializeMellowSymbioticVault(
            _symbioticVault,
            _withdrawalQueue,
            _limit,
            _depositPause,
            _withdrawalPause,
            _depositWhitelist,
            _admin,
            _name,
            _symbol
        );
        _isEntity[address(vault)] = true;
        _entities.push(address(vault));
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
