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

    function pushEigenLayerWithdrawals(address[] calldata eigenLayerVaults, uint256 maxWithdrawals)
        external
    {
        address sender = msg.sender;
        for (uint256 i = 0; i < eigenLayerVaults.length; i++) {
            IEigenLayerWithdrawalQueue withdrawalQueue = IEigenLayerWithdrawalQueue(
                address(IQueuedVault(eigenLayerVaults[i]).withdrawalQueue())
            );
            uint256 maxWithdrawalRequests = withdrawalQueue.maxWithdrawalRequests();
        }
    }
}
