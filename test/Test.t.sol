// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";

// import "../src/EthVaultV2.sol";

contract Tests is Test {
    function test() external view {
        console2.logBytes32(
            keccak256(abi.encode(uint256(keccak256("mellow.simple-lrt.storage.VaultStorage")) - 1))
                & ~bytes32(uint256(0xff))
        );
    }
}
