// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IIsolatedEigenLayerVault} from "../adapters/IIsolatedEigenLayerVault.sol";
import {IWithdrawalQueue} from "./IWithdrawalQueue.sol";
import {IDelegationManager} from "@eigenlayer-interfaces/IDelegationManager.sol";
import {IStrategy} from "@eigenlayer-interfaces/IStrategy.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
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

    function delegation() external view returns (address);

    function strategy() external view returns (address);

    function operator() external view returns (address);

    function latestWithdrawableBlock() external view returns (uint256);

    function getAccountData(
        address account,
        uint256 withdrawalsLimit,
        uint256 withdrawalsOffset,
        uint256 transferedWithdrawalsLimit,
        uint256 transferedWithdrawalsOffset
    )
        external
        view
        returns (
            uint256 claimableAssets,
            uint256[] memory withdrawals,
            uint256[] memory transferedWithdrawals
        );

    function getWithdrawalRequest(uint256 index, address account)
        external
        view
        returns (
            IDelegationManager.Withdrawal memory data,
            uint256 assets,
            uint256 shares,
            bool isClaimed,
            uint256 accountShares
        );

    function initialize(address isolatedVault_, address strategy_, address operator_) external;

    function request(address account, uint256 assets, bool isSelfRequested) external;

    function handleWithdrawals(address account) external;

    function acceptPendingAssets(address account, uint256[] calldata withdrawals_) external;
}
