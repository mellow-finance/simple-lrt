// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/queues/IEigenLayerWithdrawalQueue.sol";
import "../interfaces/vaults/IMultiVault.sol";

/**
 * @title Claimer
 * @notice Handles accepting pending assets and claiming withdrawals across multiple subvaults.
 * @dev Facilitates interaction with `IMultiVault` and its associated withdrawal queues.
 */
contract Claimer {
    /**
     * @notice Accepts pending assets and claims withdrawals for multiple subvaults.
     * @dev Iterates through the provided subvault indices and performs actions based on the protocol type.
     * Requirements:
     * - Caller must have sufficient permissions in the underlying withdrawal queues.
     * @param multiVault Address of the `IMultiVault` contract.
     * @param subvaultIndices Array of subvault indices in the `multiVault`.
     * @param indices Array of withdrawal indices for each subvault.
     * @param recipient Address to receive the claimed assets.
     * @param maxAssets Maximum amount of assets to claim across all subvaults.
     * @return assets Total amount of assets claimed.
     */
    function multiAcceptAndClaim(
        address multiVault,
        uint256[] calldata subvaultIndices,
        uint256[][] calldata indices,
        address recipient,
        uint256 maxAssets
    ) public returns (uint256 assets) {
        address sender = msg.sender;
        IMultiVaultStorage.Subvault memory subvault;
        for (uint256 i = 0; i < subvaultIndices.length; i++) {
            subvault = IMultiVault(multiVault).subvaultAt(subvaultIndices[i]);
            if (subvault.protocol == IMultiVaultStorage.Protocol.EIGEN_LAYER) {
                IEigenLayerWithdrawalQueue(subvault.withdrawalQueue).acceptPendingAssets(
                    sender, indices[i]
                );
            }
            if (subvault.withdrawalQueue != address(0) && assets < maxAssets) {
                assets += IWithdrawalQueue(subvault.withdrawalQueue).claim(
                    sender, recipient, maxAssets - assets
                );
            }
        }
    }
}
