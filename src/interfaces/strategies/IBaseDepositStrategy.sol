// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IBaseDepositStrategy {
    struct Data {
        uint256 subvaultIndex;
        uint256 depositAmount;
    }

    function calculateDepositAmounts(address metaVault, uint256 amount)
        external
        view
        returns (Data[] memory subvaultsData);
}
