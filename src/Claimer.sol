// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./EigenLayerWithdrawalQueue.sol";
import "./interfaces/vaults/IQueuedVault.sol";

contract Claimer {
    function multiClaim(address[] calldata vaults, address recipient, uint256 maxAssets)
        external
        returns (uint256 assets)
    {
        address sender = msg.sender;
        for (uint256 i = 0; i < vaults.length; i++) {
            IWithdrawalQueue withdrawalQueue = IQueuedVault(vaults[i]).withdrawalQueue();
            uint256 claimedAmount = withdrawalQueue.claim(sender, recipient, maxAssets);
            maxAssets -= claimedAmount;
            assets += claimedAmount;
            if (maxAssets == 0) {
                break;
            }
        }
    }

    /**
     * @dev The `transferedWithdrawalIndices` array is computed off-chain and contains
     * only the indices of withdrawals with significant asset values that have already been transferred.
     */
    function acceptPendingRequests(address vault, uint256[] calldata transferedWithdrawalIndices)
        public
    {
        address account = msg.sender;
        IEigenLayerWithdrawalQueue withdrawalQueue =
            IEigenLayerWithdrawalQueue(address(IQueuedVault(vault).withdrawalQueue()));
        withdrawalQueue.acceptPendingAssets(account, transferedWithdrawalIndices);
    }

    function calculatePendingRequests(address vault, address account, uint256 minValue)
        external
        view
        returns (uint256[] memory indices)
    {
        EigenLayerWithdrawalQueue withdrawalQueue =
            EigenLayerWithdrawalQueue(address(IQueuedVault(vault).withdrawalQueue()));
        uint256[] memory pendingIndices =
            withdrawalQueue.transferedWithdrawalIndicesOf(account, type(uint256).max, 0);
        (bool[] memory isClaimed, bool[] memory isClaimable, uint256[] memory assets) =
            withdrawalQueue.balancesOf(account, pendingIndices);
        indices = new uint256[](pendingIndices.length);
        uint256 iterator = 0;
        for (uint256 i = 0; i < pendingIndices.length; i++) {
            if (assets[i] >= minValue && (isClaimed[i] || isClaimable[i])) {
                indices[iterator++] = pendingIndices[i];
            }
        }
        assembly {
            mstore(indices, iterator)
        }
    }
}
