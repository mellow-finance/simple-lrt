// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

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
}
