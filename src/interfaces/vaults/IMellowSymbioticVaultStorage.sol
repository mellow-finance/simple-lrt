// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IDefaultCollateral} from "../symbiotic/IDefaultCollateral.sol";
import {ISymbioticVault} from "../symbiotic/ISymbioticVault.sol";
import {IWithdrawalQueue} from "../utils/IWithdrawalQueue.sol";

interface IMellowSymbioticVaultStorage {
    struct FarmData {
        address symbioticFarm;
        address distributionFarm;
        address curatorTreasury;
        uint256 curatorFeeD4;
    }

    struct SymbioticStorage {
        IDefaultCollateral symbioticCollateral;
        ISymbioticVault symbioticVault;
        IWithdrawalQueue withdrawalQueue;
        EnumerableSet.AddressSet rewardTokens;
        mapping(address rewardToken => FarmData data) farms;
    }

    function symbioticVault() external view returns (ISymbioticVault);

    function symbioticCollateral() external view returns (IDefaultCollateral);
}
