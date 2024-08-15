// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISymbioticVault} from "./interfaces/symbiotic/ISymbioticVault.sol";
import {IDefaultCollateral} from "./interfaces/symbiotic/IDefaultCollateral.sol";
import {IVault} from "./interfaces/vaults/IVault.sol";

contract SymbioticWithdrawalQueue {
    using SafeERC20 for IDefaultCollateral;

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

    address immutable vault;
    ISymbioticVault public immutable symbioticVault;
    IDefaultCollateral immutable collateral;

    mapping(uint256 epoch => EpochData data) private _epochData;
    mapping(address account => AccountData data) private _accountData;

    function currentEpoch() public view returns (uint256) {
        return symbioticVault.currentEpoch();
    }

    constructor(address _vault) {
        vault = _vault;
        symbioticVault = IVault(_vault).symbioticVault();
        collateral = IDefaultCollateral(symbioticVault.collateral());
    }

    function registerWithdrawal(address account, uint256 amount) external {
        require(msg.sender == vault, "SymbioticWithdrawalQueue: forbidden");

        AccountData storage accountData = _accountData[account];

        uint256 epoch_ = currentEpoch();
        _handlePendingEpochs(accountData, epoch_);

        epoch_ = epoch_ + 1;
        EpochData storage epochData = _epochData[epoch_];
        epochData.pendingShares += amount;

        accountData.pendingShares[epoch_] += amount;
        accountData.claimEpoch = epoch_;
    }

    // permissionless functon
    function handlePendingEpochs(address account) public {
        _handlePendingEpochs(_accountData[account], currentEpoch());
    }

    function _handlePendingEpochs(AccountData storage accountData, uint256 currentEpoch_) private {
        uint256 epoch_ = accountData.claimEpoch;
        if (epoch_ > 0) {
            _handlePendingEpoch(accountData, epoch_ - 1, currentEpoch_);
        }
        _handlePendingEpoch(accountData, epoch_, currentEpoch_);
    }

    function _handlePendingEpoch(
        AccountData storage accountData,
        uint256 epoch_,
        uint256 currentEpoch_
    ) private {
        if (!_isClaimable(epoch_, currentEpoch_)) {
            return;
        }
        uint256 shares_ = accountData.pendingShares[epoch_];
        if (shares_ == 0) {
            return;
        }
        EpochData storage epochData = _epochData[epoch_];
        _pull(epoch_, epochData);

        uint256 assets_ = Math.mulDiv(shares_, epochData.claimedAssets, epochData.pendingShares); // rounding down

        epochData.pendingShares -= shares_;
        epochData.claimedAssets -= assets_;

        accountData.claimableAssets += assets_;
        delete accountData.pendingShares[epoch_];
    }

    // permissionless functon
    function pull(uint256 epoch) public {
        require(_isClaimable(epoch, currentEpoch()), "SymbioticWithdrawalQueue: invalid epoch");
        _pull(epoch, _epochData[epoch]);
    }

    function _pull(uint256 epoch, EpochData storage epochData) private {
        if (epochData.isClaimed) {
            return;
        }
        epochData.isClaimed = true;
        try symbioticVault.claim(address(this), epoch) returns (uint256 claimedAssets) {
            epochData.claimedAssets = claimedAssets;
        } catch {}
    }

    function _isClaimable(uint256 epoch, uint256 currentEpoch_) private pure returns (bool) {
        return epoch < currentEpoch_;
    }

    function pending(address account)
        external
        view
        returns (uint256 pendingShares_, uint256 pendingAssets_)
    {
        uint256 epoch_ = currentEpoch();

        AccountData storage accountData = _accountData[account];
        pendingShares_ = accountData.pendingShares[epoch_] + accountData.pendingShares[epoch_ + 1];

        uint256 activeShares = symbioticVault.activeShares();
        uint256 activeStake = symbioticVault.activeStake();
        pendingAssets_ = Math.mulDiv(pendingShares_, activeStake, activeShares); // rounding down
    }

    function claimable(address account) external view returns (uint256 claimableAssets_) {
        AccountData storage accountData = _accountData[account];
        claimableAssets_ = accountData.claimableAssets;

        uint256 currentEpoch_ = currentEpoch();
        uint256 epoch_ = accountData.claimEpoch;
        if (epoch_ <= currentEpoch_) {
            if (epoch_ > 0) {
                claimableAssets_ += _claimable(account, accountData, epoch_ - 1);
            }

            if (epoch_ < currentEpoch_) {
                claimableAssets_ += _claimable(account, accountData, epoch_);
            }
        }
    }

    function _claimable(address account, AccountData storage accountData, uint256 epoch_)
        private
        view
        returns (uint256)
    {
        uint256 shares_ = accountData.pendingShares[epoch_];
        if (shares_ == 0) {
            return 0;
        }
        EpochData storage epochData = _epochData[epoch_];
        if (epochData.isClaimed) {
            return Math.mulDiv(shares_, epochData.claimedAssets, epochData.pendingShares); // rounding down
        }
        return symbioticVault.withdrawalsOf(epoch_, account);
    }

    function claim(address recipient) external returns (uint256 amount) {
        address account = msg.sender;
        AccountData storage accountData = _accountData[account];
        _handlePendingEpochs(accountData, currentEpoch());
        amount = accountData.claimableAssets;
        if (amount == 0) {
            return 0;
        }
        accountData.claimableAssets = 0;
        collateral.safeTransfer(recipient, amount);
    }
}
