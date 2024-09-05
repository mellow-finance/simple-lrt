// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../Imports.sol";

contract MockMellowSymbioticVaultStorage is MellowSymbioticVaultStorage {
    constructor(bytes32 name, uint256 version) MellowSymbioticVaultStorage(name, version) {}

    function initializeMellowSymbioticVaultStorage(
        address _symbioticCollateral,
        address _symbioticVault,
        address _withdrawalQueue
    ) external initializer {
        __initializeMellowSymbioticVaultStorage(
            _symbioticCollateral, _symbioticVault, _withdrawalQueue
        );
    }

    function setFarm(uint256 farmId, FarmData memory farmData) external {
        _setFarm(farmId, farmData);
    }

    function test() private pure {}
}
