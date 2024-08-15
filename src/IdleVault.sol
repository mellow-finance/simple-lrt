// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {SimpleVault} from "./SimpleVault.sol";

contract IdleVault is SimpleVault {
    constructor() SimpleVault("IdleVault", 1) {}

    function pushIntoSymbiotic() public override {
        // do nothing
    }
}
