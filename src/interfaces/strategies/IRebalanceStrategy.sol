// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IRebalanceStrategy {
    struct RebalanceData {
        uint256 subvaultIndex;
        uint256 claimAmount;
        uint256 depositAmount;
        uint256 withdrawalRequestAmount;
    }

    function calculateRebalanceAmounts(address vault)
        external
        view
        returns (RebalanceData[] memory subvaultsData);
}
