// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./ISemVerMixin.sol";

interface ISignatureUtils is ISemVerMixin {
    /// @notice Thrown when a signature is invalid.
    error InvalidSignature();
    /// @notice Thrown when a signature has expired.
    error SignatureExpired();

    /// @notice Struct that bundles together a signature and an expiration time for the signature.
    /// @dev Used primarily for stack management.
    struct SignatureWithExpiry {
        // the signature itself, formatted as a single bytes object
        bytes signature;
        // the expiration timestamp (UTC) of the signature
        uint256 expiry;
    }

    /// @notice Struct that bundles together a signature, a salt for uniqueness, and an expiration time for the signature.
    /// @dev Used primarily for stack management.
    struct SignatureWithSaltAndExpiry {
        // the signature itself, formatted as a single bytes object
        bytes signature;
        // the salt used to generate the signature
        bytes32 salt;
        // the expiration timestamp (UTC) of the signature
        uint256 expiry;
    }

    /// @notice Computes the EIP-712 domain separator used for signature validation.
    /// @dev The domain separator is computed according to EIP-712 specification, using:
    ///      - The hardcoded name "EigenLayer"
    ///      - The contract's version string
    ///      - The current chain ID
    ///      - This contract's address
    /// @return The 32-byte domain separator hash used in EIP-712 structured data signing.
    /// @dev See https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator.
    function domainSeparator() external view returns (bytes32);
}
