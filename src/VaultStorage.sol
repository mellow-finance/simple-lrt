// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.26;

import {IDefaultCollateral} from "./interfaces/IDefaultCollateral.sol";
import {ISymbioticVault} from "./interfaces/ISymbioticVault.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract VaultStorage {
    using EnumerableSet for EnumerableSet.AddressSet;
    uint256 public constant VERSION = 1;
    bytes32 public NAME = keccak256("Vault");
    bytes32 public immutable storageSlotRef;

    constructor() {
        storageSlotRef = keccak256(
            abi.encodePacked("VaultStorage", NAME, VERSION)
        );
    }

    struct FarmData {
        address symbioticFarm;
        address distributionFarm;
        address curatorTreasury;
        uint256 curatorFeeD4;
    }

    struct Storage {
        IDefaultCollateral symbioticCollateral;
        ISymbioticVault symbioticVault;
        address token;
        address owner;
        bool paused;
        uint256 limit;
        EnumerableSet.AddressSet rewardTokens;
        mapping(address rewardToken => FarmData data) farms;
    }

    function _contractStorage() private view returns (Storage storage $) {
        bytes32 loc = storageSlotRef;
        assembly {
            $.slot := loc
        }
    }
}
