// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/Create2.sol";

library MaskLib {
    address public constant create2DeterministicDeployer =
        0x4e59b44847b379578588920cA78FbF26c0B4956C;

    /// @dev bytes memory bytecode = abi.encodePacked(type(Contract).creationCode, abi.encode(constructorParams...))
    /// @dev bytescodeHash = keccak256(bytecode)
    function findFirst(uint256 from, uint256 to, uint256 zeros, bytes32 bytecodeHash)
        internal
        pure
        returns (uint256)
    {
        uint256 mask = type(uint160).max >> zeros;
        for (uint256 i = from; i <= to; i++) {
            address addr =
                Create2.computeAddress(bytes32(i), bytecodeHash, create2DeterministicDeployer);
            if ((uint160(addr) & mask) == uint160(addr)) {
                return i;
            }
        }
        return type(uint256).max;
    }
}
