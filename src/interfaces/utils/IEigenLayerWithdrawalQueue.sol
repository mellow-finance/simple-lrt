// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@eigenlayer-interfaces/IDelegationManager.sol";
import "@eigenlayer-interfaces/IPausable.sol";
import "@eigenlayer-interfaces/IStrategyManager.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IEigenLayerWithdrawalQueue {
    struct WithdrawalData {
        IDelegationManager.Withdrawal data;
        bool isClaimed;
        uint256 assets;
        uint256 totalSupply;
        mapping(address account => uint256) balanceOf;
    }

    struct AccountData {
        uint256 claimableAssets;
        EnumerableSet.UintSet withdrawalIndices;
        EnumerableSet.UintSet transferedWithdrawalIndices;
    }

    function MAX_WITHDRAWAL_REQUESTS() external view returns (uint256);

    function vault() external view returns (address);
    function claimer() external view returns (address);
    function collateral() external view returns (address);

    function pendingAssets() external view returns (uint256);
    function balancesOf(address account)
        external
        view
        returns (bool[] memory isClaimed, bool[] memory isClaimable, uint256[] memory assets);
    function balanceOf(address account) external view returns (uint256);
    function pendingAssetsOf(address account) external view returns (uint256);
    function claimableAssetsOf(address account) external view returns (uint256);
    function maxWithdrawalRequests() external view returns (uint256);
    function request(address account, uint256 assets, bool isSelfRequested) external;
    function withdrawalAssets(uint256 withdrawalIndex)
        external
        view
        returns (bool isClaimed, bool isClaimable, uint256 assets, uint256 shares);
    function withdrawalAssetsOf(uint256 withdrawalIndex, address account)
        external
        view
        returns (bool isClaimed, bool isClaimable, uint256 assets, uint256 shares);
    function acceptPendingAssets(address account, uint256[] calldata withdrawalIndices) external;
    function transferPendingAssets(address from, address to, uint256 amount) external;
    function pull(uint256 withdrawalIndex) external;
    function handleWithdrawals(address account) external;
    function claim(address account, address recipient, uint256 maxAmount)
        external
        returns (uint256 assets);
}
