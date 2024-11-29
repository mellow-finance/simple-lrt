// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IRebalanceStrategy {
    struct RebalanceData {
        uint256 subvaultIndex;
        uint256 claim;
        uint256 deposit;
        uint256 request;
    }

    function calculateRebalanceAmounts(address vault)
        external
        view
        returns (RebalanceData[] memory subvaultsData);
}
