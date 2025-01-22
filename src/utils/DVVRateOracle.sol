// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/tokens/IWSTETH.sol";
import "./VaultRateOracle.sol";

contract DVVRateOracle is VaultRateOracle {
    IWSTETH public WstETH;

    constructor(address vault_, address wsteth_) VaultRateOracle(vault_, address(0)) {
        WstETH = IWSTETH(wsteth_);
    }

    function _getDeprecatedRate(uint256 shares) internal view override returns (uint256) {
        // flow for mellow-lrt@Vault
        (address[] memory tokens, uint256[] memory amounts) =
            IDeprecatedVault(vault).underlyingTvl();
        require(amounts.length == 2, "VaultRateOracle: invalid length");
        uint256 wstethIndex = address(WstETH) == tokens[0] ? 0 : 1;
        uint256 wethValue = WstETH.getStETHByWstETH(amounts[wstethIndex]) + amounts[wstethIndex ^ 1];
        return Math.mulDiv(wethValue, shares, IERC20(vault).totalSupply());
    }
}
