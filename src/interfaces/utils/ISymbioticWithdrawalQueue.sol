// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {ISymbioticVault} from "../symbiotic/ISymbioticVault.sol";
import {IDefaultCollateral} from "../symbiotic/IDefaultCollateral.sol";
import {IVault} from "../vaults/IVault.sol";

import {IWithdrawalQueue} from "./IWithdrawalQueue.sol";

interface ISymbioticWithdrawalQueue is IWithdrawalQueue {
    struct EpochData {
        uint256 pendingShares;
        bool isClaimed;
        uint256 claimedAssets;
    }

    struct AccountData {
        mapping(uint256 epoch => uint256 shares) pendingShares;
        uint256 claimableAssets;
        uint256 claimEpoch;
    }

    function vault() external view returns (address);

    function symbioticVault() external view returns (ISymbioticVault);

    function collateral() external view returns (IDefaultCollateral);

    function currentEpoch() external view returns (uint256);

    // permissionless functon
    function handlePendingEpochs(address account) external;

    // permissionless functon
    function pull(uint256 epoch) external;
}
