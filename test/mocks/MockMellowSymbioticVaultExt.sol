// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../Imports.sol";

contract MockMellowSymbioticVaultExt is MellowSymbioticVault {
    constructor() MellowSymbioticVault("MellowSymbioticVault", 1) {}

    function calculatePushAmounts() external view returns (uint256, uint256, uint256) {
        return _calculatePushAmounts(IERC20(asset()), symbioticCollateral(), symbioticVault());
    }

    function calculateSymbioticVaultLeftover(ISymbioticVault vault)
        external
        view
        returns (uint256)
    {
        return _calculateSymbioticVaultLeftover(vault);
    }

    function test() private pure {}
}
