// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IMellowSymbioticVault} from "../vaults/IMellowSymbioticVault.sol";
import {IVault as ISymbioticVault} from "@symbiotic/core/interfaces/vault/IVault.sol";

import {IWithdrawalQueue} from "./IWithdrawalQueue.sol";

interface ISymbioticWithdrawalQueue is IWithdrawalQueue {
    struct EpochData {
        bool isClaimed;
        uint256 sharesToClaim;
        uint256 claimableAssets;
    }

    struct AccountData {
        mapping(uint256 epoch => uint256 shares) sharesToClaim;
        uint256 claimableAssets;
        uint256 claimEpoch;
    }

    function vault() external view returns (address);

    function symbioticVault() external view returns (ISymbioticVault);

    function getCurrentEpoch() external view returns (uint256);

    function handlePendingEpochs(address account) external;

    function pull(uint256 epoch) external;

    event WithdrawalRequested(address account, uint256 epoch, uint256 amount);
    event EpochClaimed(uint256 epoch, uint256 claimedAssets);
    event EpochClaimFailed(uint256 epoch);
    event Claimed(address account, address recipient, uint256 amount);
}
