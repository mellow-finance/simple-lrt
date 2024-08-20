// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IDefaultCollateral} from "../symbiotic/IDefaultCollateral.sol";
import {ISymbioticVault} from "../symbiotic/ISymbioticVault.sol";
import {IWithdrawalQueue} from "../utils/IWithdrawalQueue.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IMellowSymbioticVaultStorage {
    struct FarmData {
        address rewardToken;
        address symbioticFarm;
        address distributionFarm;
        address curatorTreasury;
        uint256 curatorFeeD6;
    }

    struct SymbioticStorage {
        ISymbioticVault symbioticVault;
        IWithdrawalQueue withdrawalQueue;
        EnumerableSet.UintSet farmIds;
        mapping(uint256 farmId => FarmData data) farms;
    }

    function symbioticVault() external view returns (ISymbioticVault);

    event SymbioticVaultSet(address symbioticVault, uint256 timestamp);

    event WithdrawalQueueSet(address withdrawalQueue, uint256 timestamp);

    event FarmSet(uint256 farmId, FarmData farmData, uint256 timestamp);
}
