// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IBaseRebalanceStrategy {
    struct Data {
        uint256 subvaultIndex;
        uint256 claimAmount;
        uint256 depositAmount;
        uint256 withdrawalRequestAmount;
    }

    function calculateRebalaneAmounts(address metaVault)
        external
        view
        returns (Data[] memory subvaultsData);
}
