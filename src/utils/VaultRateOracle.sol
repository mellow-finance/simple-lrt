// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/tokens/IWSTETH.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract VaultRateOracle {
    address public immutable vault;
    address public immutable wsteth;

    constructor(address vault_, address wsteth_) {
        vault = vault_;
        wsteth = wsteth_;
    }

    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        assets = IERC4626(vault).convertToAssets(shares);
        if (wsteth != address(0)) {
            // we assume the price is in WSTETH token, so we want to convert it to ETH
            assets = IWSTETH(wsteth).getStETHByWstETH(assets);
        }
    }

    function getRate() external view returns (uint256) {
        return convertToAssets(1 ether);
    }
}
