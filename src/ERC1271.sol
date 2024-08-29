// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";

contract ERC1271 {
    // bytes4(keccak256("isValidSignature(bytes32,bytes)")
    bytes4 internal constant MAGIC_VALUE = 0x1626ba7e;
    mapping(bytes32 => bool) private _signedHashes;

    /**
     * @dev Should return whether the signature provided is valid for the provided data
     * @param hash      Hash of the data to be signed
     * @param signature Signature byte array associated with _data
     */
    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
        returns (bytes4 magicValue)
    {
        if (_signedHashes[hash]) {
            bytes32 signatureHash = abi.decode(signature, (bytes32));
            require(
                signatureHash == keccak256(abi.encode(address(this), block.timestamp, hash)),
                "ERC1271: wrong signature"
            );
            return MAGIC_VALUE;
        } else {
            return 0xffffffff;
        }
    }

    function _setHashAsSigned(bytes32 hash) internal {
        _signedHashes[hash] = true;
    }

    function _revokeHash(bytes32 hash) internal {
        _signedHashes[hash] = false;
    }
}
