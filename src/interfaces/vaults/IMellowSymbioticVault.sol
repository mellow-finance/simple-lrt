// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./IERC4626Vault.sol";
import "./IVaultControlStorage.sol";

interface IMellowSymbioticVault is IERC4626Vault, IVaultControlStorage {
    function compatTotalSupply() external view returns (uint256);
    function defaultCollateral() external view returns (address);
    function symbioticVault() external view returns (address);
}
