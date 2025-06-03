// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/tokens/IWSTETH.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract Oracle {
    address public constant WstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public immutable vault;
    bool public immutable isETHBased;

    constructor(address vault_, bool isETHBased_) {
        vault = vault_;
        if (isETHBased_) {
            require(IERC4626(vault).asset() == WstETH, "Oracle: vault asset is not WstETH");
        }
        isETHBased = isETHBased_;
    }

    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        assets = IERC4626(vault).convertToAssets(shares);
        if (isETHBased) {
            // we assume the price is in WSTETH token, so we want to convert it to ETH
            assets = IWSTETH(WstETH).getStETHByWstETH(assets);
        }
    }

    function getRate() external view returns (uint256) {
        return convertToAssets(1 ether);
    }
}
