// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IDefaultCollateral} from "./IDefaultCollateral.sol";
import {ISymbioticVault} from "./ISymbioticVault.sol";

interface IVaultStorage {
    // uint256 public constant VERSION = 1;
    // bytes32 public NAME = keccak256("Vault");
    // bytes32 public immutable storageSlotRef;

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

    function initialize(
        address _symbioticCollateral,
        address _symbioticVault,
        uint256 _limit,
        address _owner,
        bool _paused
    ) external;

    function symbioticCollateral() external view returns (IDefaultCollateral);

    function symbioticVault() external view returns (ISymbioticVault);

    function token() external view returns (address);

    function owner() external view returns (address);

    function paused() external view returns (bool);

    function limit() external view returns (uint256);

    function symbioticRewardTokens() external view returns (address[] memory);

    function symbioticFarm(address rewardToken) external view returns (FarmData memory);
}
