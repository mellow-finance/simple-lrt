// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/utils/ISymbioticWithdrawalQueue.sol";
import "forge-std/Test.sol";

contract SymbioticWithdrawalQueue is ISymbioticWithdrawalQueue {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /// @inheritdoc ISymbioticWithdrawalQueue
    address public immutable vault;
    /// @inheritdoc ISymbioticWithdrawalQueue
    ISymbioticVault public immutable symbioticVault;
    /// @inheritdoc ISymbioticWithdrawalQueue
    address public immutable collateral;

    mapping(uint256 epoch => EpochData data) public _epochData;
    mapping(address account => AccountData data) private _accountData;

    constructor(address _vault, address _symbioticVault) {
        vault = _vault;
        symbioticVault = ISymbioticVault(_symbioticVault);
        collateral = symbioticVault.collateral();
    }

    /// @inheritdoc ISymbioticWithdrawalQueue
    function getCurrentEpoch() public view returns (uint256) {
        return symbioticVault.currentEpoch();
    }

    /// @inheritdoc ISymbioticWithdrawalQueue
    function getEpochData(uint256 epoch) external view returns (EpochData memory) {
        return _epochData[epoch];
    }

    /// @inheritdoc ISymbioticWithdrawalQueue
    function pendingAssets() public view returns (uint256) {
        uint256 epoch = getCurrentEpoch();
        address this_ = address(this);
        return symbioticVault.withdrawalsOf(epoch, this_)
            + symbioticVault.withdrawalsOf(epoch + 1, this_);
    }

    /// @inheritdoc ISymbioticWithdrawalQueue
    function balanceOf(address account) public view returns (uint256) {
        return claimableAssetsOf(account) + pendingAssetsOf(account);
    }

    /// @inheritdoc ISymbioticWithdrawalQueue
    function pendingAssetsOf(address account) public view returns (uint256 assets) {
        uint256 epoch = getCurrentEpoch();

        AccountData storage accountData = _accountData[account];
        assets += _withdrawalsOf(epoch, accountData.sharesToClaim[epoch]);
        epoch += 1;
        assets += _withdrawalsOf(epoch, accountData.sharesToClaim[epoch]);
    }

    /// @inheritdoc ISymbioticWithdrawalQueue
    function claimableAssetsOf(address account) public view returns (uint256 assets) {
        AccountData storage accountData = _accountData[account];
        assets = accountData.claimableAssets;

        uint256 currentEpoch = getCurrentEpoch();
        uint256 epoch = accountData.claimEpoch;
        if (epoch > 0 && _isClaimableInSymbiotic(epoch - 1, currentEpoch)) {
            assets += _claimable(accountData, epoch - 1);
        }

        if (_isClaimableInSymbiotic(epoch, currentEpoch)) {
            assets += _claimable(accountData, epoch);
        }
    }

    /// @inheritdoc ISymbioticWithdrawalQueue
    function request(address account, uint256 amount) external {
        require(msg.sender == vault, "SymbioticWithdrawalQueue: forbidden");
        if (amount == 0) {
            return;
        }
        AccountData storage accountData = _accountData[account];

        uint256 epoch = getCurrentEpoch();
        _handlePendingEpochs(accountData, epoch);

        epoch = epoch + 1;
        EpochData storage epochData = _epochData[epoch];
        epochData.sharesToClaim += amount;

        accountData.sharesToClaim[epoch] += amount;
        accountData.claimEpoch = epoch;
        emit WithdrawalRequested(account, epoch, amount);
    }

    /// @inheritdoc ISymbioticWithdrawalQueue
    function pull(uint256 epoch) public {
        require(
            _isClaimableInSymbiotic(epoch, getCurrentEpoch()),
            "SymbioticWithdrawalQueue: invalid epoch"
        );
        _pullFromSymbioticForEpoch(epoch);
    }

    /// @inheritdoc ISymbioticWithdrawalQueue
    function claim(address account, address recipient, uint256 maxAmount)
        external
        returns (uint256 amount)
    {
        address sender = msg.sender;
        require(sender == account || sender == vault, "SymbioticWithdrawalQueue: forbidden");
        AccountData storage accountData = _accountData[account];
        _handlePendingEpochs(accountData, getCurrentEpoch());
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
        if (amount != 0) {
            IERC20(collateral).safeTransfer(recipient, amount);
        }
        emit Claimed(account, recipient, amount);
    }

    /// @inheritdoc ISymbioticWithdrawalQueue
    function handlePendingEpochs(address account) public {
        _handlePendingEpochs(_accountData[account], getCurrentEpoch());
    }

    /**
     * @notice Returns amount of `assets` that will be withdrawn for the corresponding `shares`.
     * @param epoch Number of the Simbiotic epoch.
     * @param shares Withdrawal shares.
     * @return assets Amount of assets corresponding to `shares` that will be withdrawn.
     */
    function _withdrawalsOf(uint256 epoch, uint256 shares) private view returns (uint256) {
        if (shares == 0) {
            return 0;
        }
        return shares.mulDiv(
            symbioticVault.withdrawalsOf(epoch, address(this)), _epochData[epoch].sharesToClaim
        );
    }

    function _handlePendingEpochs(AccountData storage accountData, uint256 currentEpoch) private {
        uint256 epoch = accountData.claimEpoch;
        if (epoch > 0) {
            _handlePendingEpoch(accountData, epoch - 1, currentEpoch);
        }
        _handlePendingEpoch(accountData, epoch, currentEpoch);
    }

    function _handlePendingEpoch(
        AccountData storage accountData,
        uint256 epoch,
        uint256 currentEpoch
    ) private {
        if (!_isClaimableInSymbiotic(epoch, currentEpoch)) {
            return;
        }
        uint256 shares = accountData.sharesToClaim[epoch];
        if (shares == 0) {
            return;
        }
        _pullFromSymbioticForEpoch(epoch);

        EpochData storage epochData = _epochData[epoch];
        uint256 assets = shares.mulDiv(epochData.claimableAssets, epochData.sharesToClaim);

        epochData.sharesToClaim -= shares;
        epochData.claimableAssets -= assets;

        accountData.claimableAssets += assets;
        delete accountData.sharesToClaim[epoch];
    }

    function _pullFromSymbioticForEpoch(uint256 epoch) private {
        EpochData storage epochData = _epochData[epoch];
        if (epochData.isClaimed) {
            return;
        }
        epochData.isClaimed = true;
        address this_ = address(this);
        if (symbioticVault.isWithdrawalsClaimed(epoch, this_)) {
            return;
        }
        if (symbioticVault.withdrawalsOf(epoch, this_) == 0) {
            return;
        }
        uint256 claimedAssets = symbioticVault.claim(this_, epoch);
        epochData.claimableAssets = claimedAssets;
        emit EpochClaimed(epoch, claimedAssets);
    }

    function _claimable(AccountData storage accountData, uint256 epoch)
        private
        view
        returns (uint256)
    {
        uint256 shares = accountData.sharesToClaim[epoch];
        if (shares == 0) {
            return 0;
        }
        EpochData storage epochData = _epochData[epoch];
        if (epochData.isClaimed) {
            return shares.mulDiv(epochData.claimableAssets, epochData.sharesToClaim);
        }
        return _withdrawalsOf(epoch, shares);
    }

    /**
     * Returns wheter `epoch` is claimable if `currentEpoch` is current epoch.
     * @param epoch Number of epoch to check.
     * @param currentEpoch Nmber of Current epoch.
     */
    function _isClaimableInSymbiotic(uint256 epoch, uint256 currentEpoch)
        private
        pure
        returns (bool)
    {
        return epoch < currentEpoch;
    }
}
