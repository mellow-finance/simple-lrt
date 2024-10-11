// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IWSTETH} from "../../../src/interfaces/tokens/IWSTETH.sol";

contract WStethOracle {
    address public immutable wsteth;

    constructor(address wsteth_) {
        wsteth = wsteth_;
    }

    function priceX96() external view returns (uint256) {
        return IWSTETH(wsteth).getStETHByWstETH(2 ** 96);
    }
}
