// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IIsolatedEigenLayerVault} from "../adapters/IIsolatedEigenLayerVault.sol";
import {IWithdrawalQueue} from "./IWithdrawalQueue.sol";
import {IDelegationManager} from "@eigenlayer-interfaces/IDelegationManager.sol";
import {IStrategy} from "@eigenlayer-interfaces/IStrategy.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IEigenLayerWithdrawalQueue is IWithdrawalQueue {
    struct WithdrawalData {
        IDelegationManager.Withdrawal data;
        bool isClaimed;
        uint256 assets;
        uint256 shares;
        mapping(address account => uint256) sharesOf;
    }

    struct AccountData {
        uint256 claimableAssets;
        EnumerableSet.UintSet withdrawals;
        EnumerableSet.UintSet transferedWithdrawals;
    }

    function isolatedVault() external view returns (address);
    function claimer() external view returns (address);
    function asset() external view returns (address);
    function delegation() external view returns (address);
    function strategy() external view returns (address);
    function operator() external view returns (address);

    function latestWithdrawableBlock() external view returns (uint256);

    function request(address account, uint256 assets, bool isSelfRequested) external;

    function handleWithdrawals(address account) external;

    function acceptPendingAssets(address account, uint256[] calldata withdrawals_) external;
}
