// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

contract MockAVS {
    function supportsAVS(address) external pure returns (bool) {
        return true;
    }

    fallback() external {}
}
