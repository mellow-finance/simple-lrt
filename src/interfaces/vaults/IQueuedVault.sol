// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../utils/IWithdrawalQueue.sol";

interface IQueuedVault {
    function withdrawalQueue() external view returns (IWithdrawalQueue);

    function claimableAssetsOf(address account) external view returns (uint256 claimableAssets);

    function pendingAssetsOf(address account) external view returns (uint256 pendingAssets);

    function claim(address account, address recipient, uint256 maxAmount)
        external
        returns (uint256);

    function getBalances(address account)
        external
        view
        returns (
            uint256 accountAssets,
            uint256 accountInstantAssets,
            uint256 accountShares,
            uint256 accountInstantShares
        );
}
