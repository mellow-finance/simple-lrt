// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IDefaultCollateral} from "../symbiotic/IDefaultCollateral.sol";
import {ISymbioticVault} from "../symbiotic/ISymbioticVault.sol";
import {IWithdrawalQueue} from "../utils/IWithdrawalQueue.sol";

interface IVaultStorage {
    struct FarmData {
        address symbioticFarm;
        address distributionFarm;
        address curatorTreasury;
        uint256 curatorFeeD4;
    }

    struct Storage {
        IDefaultCollateral symbioticCollateral;
        ISymbioticVault symbioticVault;
        IWithdrawalQueue withdrawalQueue;
        bool depositPause;
        bool withdrawalPause;
        uint256 limit;
        EnumerableSet.AddressSet rewardTokens;
        mapping(address rewardToken => FarmData data) farms;
    }

    function symbioticVault() external view returns (ISymbioticVault);
}
