// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./IOracle.sol";

contract ConstantOracle is IOracle {
    uint256 public immutable priceX96;

    constructor(uint256 priceX96_) {
        priceX96 = priceX96_;
    }
}
