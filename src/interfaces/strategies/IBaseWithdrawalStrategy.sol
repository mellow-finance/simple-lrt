// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IBaseWithdrawalStrategy {
    struct Data {
        uint256 subvaultIndex;
        uint256 claimAmount;
        uint256 withdrawalTransferPendingAmount;
        uint256 withdrawalRequestAmount;
    }

    function calculateWithdrawalAmounts(address metaVault, uint256 amount)
        external
        view
        returns (Data[] memory subvaultsData);
}
