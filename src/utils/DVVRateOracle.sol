// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/tokens/IWSTETH.sol";
import "./VaultRateOracle.sol";

contract DVVRateOracle is VaultRateOracle {
    address public immutable wsteth;

    constructor(address vault_, address wsteth_) VaultRateOracle(vault_) {
        wsteth = wsteth_;
    }

    function _getDeprecatedRate(uint256 shares) internal view override returns (uint256) {
        // flow for mellow-lrt@Vault
        (address[] memory tokens, uint256[] memory amounts) =
            IDeprecatedVault(vault).underlyingTvl();
        require(amounts.length == 2, "VaultRateOracle: invalid length");
        uint256 wstethIndex = wsteth == tokens[0] ? 0 : 1;
        uint256 wstethValue =
            amounts[wstethIndex] + IWSTETH(wsteth).getWstETHByStETH(amounts[wstethIndex ^ 1]);
        return Math.mulDiv(wstethValue, shares, IERC20(vault).totalSupply());
    }
}
