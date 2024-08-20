// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/utils/ISymbioticWithdrawalQueue.sol";

contract SymbioticWithdrawalQueue is ISymbioticWithdrawalQueue {
    using SafeERC20 for IDefaultCollateral;
    using Math for uint256;

    address public immutable vault;
    ISymbioticVault public immutable symbioticVault;
    IDefaultCollateral public immutable collateral;
    uint256 public claimableAssets;

    mapping(uint256 epoch => EpochData data) private _epochData;
    mapping(address account => AccountData data) private _accountData;

    constructor(address _vault, address _symbioticVault) {
        vault = _vault;
        symbioticVault = ISymbioticVault(_symbioticVault);
        collateral = IDefaultCollateral(symbioticVault.collateral());
    }

    function currentEpoch() public view returns (uint256) {
        return symbioticVault.currentEpoch();
    }

    // --- total balances ---

    function totalAssets() external view returns (uint256) {
        return claimableAssets + pendingAssets();
    }

    function pendingAssets() public view returns (uint256) {
        uint256 epoch = currentEpoch();
        address this_ = address(this);
        return symbioticVault.withdrawalsOf(epoch, this_)
            + symbioticVault.withdrawalsOf(epoch + 1, this_);
    }

    // --- user balances ---

    function balanceOf(address account) public view returns (uint256) {
        return claimableAssetsOf(account) + pendingAssetsOf(account);
    }

    function pendingAssetsOf(address account) public view returns (uint256 pendingAssets_) {
        uint256 epoch_ = currentEpoch();

        AccountData storage accountData = _accountData[account];
        uint256 sharesToClaim =
            accountData.sharesToClaim[epoch_] + accountData.sharesToClaim[epoch_ + 1];

        uint256 activeShares = symbioticVault.activeShares();
        uint256 activeStake = symbioticVault.activeStake();
        if (sharesToClaim == 0 || activeStake == 0) {
            return 0;
        }
        pendingAssets_ = sharesToClaim.mulDiv(activeStake, activeShares); // rounding down
    }

    function claimableAssetsOf(address account) public view returns (uint256 claimableAssets_) {
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

    // --- actions ---

    function request(address account, uint256 amount) external {
        require(msg.sender == vault, "SymbioticWithdrawalQueue: forbidden");
        if (amount == 0) {
            return;
        }
        AccountData storage accountData = _accountData[account];

        uint256 epoch_ = currentEpoch();
        _handlePendingEpochs(accountData, epoch_);

        epoch_ = epoch_ + 1;
        EpochData storage epochData = _epochData[epoch_];
        epochData.sharesToClaim += amount;

        accountData.sharesToClaim[epoch_] += amount;
        accountData.claimEpoch = epoch_;
        emit WithdrawalRequested(account, epoch_, amount);
    }

    // permissionless functon
    function pull(uint256 epoch) public {
        require(
            _isClaimableInSymbiotic(epoch, currentEpoch()),
            "SymbioticWithdrawalQueue: invalid epoch"
        );
        _pullFromSymbioticForEpoch(epoch);
    }

    function claim(address account, address recipient, uint256 maxAmount)
        external
        returns (uint256 amount)
    {
        address sender = msg.sender;
        require(sender == account || sender == vault, "SymbioticWithdrawalQueue: forbidden");
        AccountData storage accountData = _accountData[account];
        _handlePendingEpochs(accountData, currentEpoch());
        amount = accountData.claimableAssets;
        if (amount == 0) {
            return 0;
        }
        if (amount <= maxAmount) {
            accountData.claimableAssets = 0;
        } else {
            amount = maxAmount;
            accountData.claimableAssets -= maxAmount;
        }
        claimableAssets -= amount;
        if (amount != 0) {
            collateral.safeTransfer(recipient, amount);
        }
        emit Claimed(account, recipient, amount);
    }

    // permissionless functon
    function handlePendingEpochs(address account) public {
        _handlePendingEpochs(_accountData[account], currentEpoch());
    }

    // --- internal functions ---

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
        if (!_isClaimableInSymbiotic(epoch_, currentEpoch_)) {
            return;
        }
        uint256 shares_ = accountData.sharesToClaim[epoch_];
        if (shares_ == 0) {
            return;
        }
        _pullFromSymbioticForEpoch(epoch_);

        EpochData storage epochData = _epochData[epoch_];
        uint256 assets_ = shares_.mulDiv(epochData.claimableAssets, epochData.sharesToClaim);

        epochData.sharesToClaim -= shares_;
        epochData.claimableAssets -= assets_;

        accountData.claimableAssets += assets_;
        delete accountData.sharesToClaim[epoch_];
    }

    function _pullFromSymbioticForEpoch(uint256 epoch) private {
        EpochData storage epochData = _epochData[epoch];
        if (epochData.isClaimed) {
            return;
        }
        epochData.isClaimed = true;
        try symbioticVault.claim(address(this), epoch) returns (uint256 claimedAssets) {
            epochData.claimableAssets = claimedAssets;
            claimableAssets += claimedAssets;
            emit EpochClaimed(epoch, claimedAssets);
        } catch {
            // if we failed to claim epoch we assume it is claimed
            // most likely low funds in epoch got additionally slashed so we can't claim it (error becase of 0 amounts)
            emit EpochClaimFailed(epoch);
        }
    }

    function _claimable(address account, AccountData storage accountData, uint256 epoch_)
        private
        view
        returns (uint256)
    {
        uint256 shares_ = accountData.sharesToClaim[epoch_];
        if (shares_ == 0) {
            return 0;
        }
        EpochData storage epochData = _epochData[epoch_];
        if (epochData.isClaimed) {
            return shares_.mulDiv(epochData.claimableAssets, epochData.sharesToClaim);
        }
        return
            shares_.mulDiv(symbioticVault.withdrawalsOf(epoch_, account), epochData.sharesToClaim);
    }

    function _isClaimableInSymbiotic(uint256 epoch, uint256 currentEpoch_)
        private
        pure
        returns (bool)
    {
        return epoch < currentEpoch_;
    }
}
