// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IWithdrawalStrategy {
    struct WithdrawalData {
        uint256 subvaultIndex;
        uint256 claimAmount;
        uint256 withdrawalTransferPendingAmount;
        uint256 withdrawalRequestAmount;
    }

    function calculateWithdrawalAmounts(address vault, uint256 amount)
        external
        view
        returns (WithdrawalData[] memory subvaultsData);
}
