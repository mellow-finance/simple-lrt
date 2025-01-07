// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

interface IDeprecatedVault {
    function underlyingTvl()
        external
        view
        returns (address[] memory tokens, uint256[] memory amounts);
}

contract VaultRateOracle {
    address public immutable vault;
    bool public isERC4626Compatible = false;

    constructor(address vault_) {
        vault = vault_;
    }

    function _getDeprecatedRate(uint256 shares) internal view virtual returns (uint256) {
        // flow for mellow-lrt@Vault
        (, uint256[] memory amounts) = IDeprecatedVault(vault).underlyingTvl();
        require(amounts.length == 1, "VaultRateOracle: invalid length");
        return Math.mulDiv(amounts[0], shares, IERC20(vault).totalSupply());
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        if (!isERC4626Compatible) {
            return _getDeprecatedRate(shares);
        }
        return IERC4626(vault).convertToAssets(shares);
    }

    function migrationCallback() external {
        require(!isERC4626Compatible, "VaultRateOracle: already migrated");
        // no revert expected
        IERC4626(vault).convertToAssets(1 ether);
        isERC4626Compatible = true;
    }
}
