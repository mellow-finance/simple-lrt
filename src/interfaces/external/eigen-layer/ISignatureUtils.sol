// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface ISignatureUtils {
    struct SignatureWithExpiry {
        bytes signature;
        uint256 expiry;
    }

    struct SignatureWithSaltAndExpiry {
        bytes signature;
        bytes32 salt;
        uint256 expiry;
    }

    function domainSeparator() external view returns (bytes32);
}
