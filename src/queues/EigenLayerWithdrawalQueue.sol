// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/queues/IEigenLayerWithdrawalQueue.sol";

contract EigenLayerWithdrawalQueue is IEigenLayerWithdrawalQueue, Initializable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    /// @inheritdoc IEigenLayerWithdrawalQueue
    uint256 public constant MAX_PENDING_WITHDRAWALS = 50;
    /// @inheritdoc IEigenLayerWithdrawalQueue
    uint256 public constant MAX_CLAIMING_WITHDRAWALS = 5;

    /// @inheritdoc IEigenLayerWithdrawalQueue
    address public immutable claimer;
    /// @inheritdoc IEigenLayerWithdrawalQueue
    address public immutable delegation;

    /// @inheritdoc IEigenLayerWithdrawalQueue
    address public isolatedVault;
    /// @inheritdoc IEigenLayerWithdrawalQueue
    address public strategy;
    /// @inheritdoc IEigenLayerWithdrawalQueue
    address public operator;
    /// @inheritdoc IEigenLayerWithdrawalQueue
    bool public isShutdown;

    WithdrawalData[] internal _withdrawals;
    mapping(address account => AccountData) internal _accountData;

    constructor(address claimer_, address delegation_) {
        claimer = claimer_;
        delegation = delegation_;
        _disableInitializers();
    }

    /// @inheritdoc IEigenLayerWithdrawalQueue
    function initialize(address isolatedVault_, address strategy_, address operator_)
        public
        virtual
        initializer
    {
        __init_EigenLayerWithdrawalQueue(isolatedVault_, strategy_, operator_);
    }

    /// --------------- EXTERNAL VIEW FUNCTIONS ---------------

    /// @inheritdoc IEigenLayerWithdrawalQueue
    function latestWithdrawableBlock() public view returns (uint256) {
        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = IStrategy(strategy);
        return block.number - IDelegationManager(delegation).getWithdrawalDelay(strategies);
    }

    /// @inheritdoc IWithdrawalQueue
    function pendingAssetsOf(address account) public view virtual returns (uint256 assets) {
        AccountData storage accountData_ = _accountData[account];
        uint256[] memory indices = accountData_.withdrawals.values();
        uint256 block_ = latestWithdrawableBlock();
        uint256 counter = 0;
        uint256 shares = 0;
        for (uint256 i = 0; i < indices.length; i++) {
            WithdrawalData storage withdrawal = _withdrawals[indices[i]];
            if (withdrawal.isClaimed) {
                continue;
            } else if (block_ >= withdrawal.data.startBlock && counter < MAX_CLAIMING_WITHDRAWALS) {
                counter++;
            } else {
                shares += withdrawal.sharesOf[account];
            }
        }
        assets = shares == 0 ? 0 : IStrategy(strategy).sharesToUnderlyingView(shares);
    }

    /// @inheritdoc IWithdrawalQueue
    function claimableAssetsOf(address account) public view virtual returns (uint256 assets) {
        AccountData storage accountData_ = _accountData[account];
        uint256[] memory indices = accountData_.withdrawals.values();
        uint256 block_ = latestWithdrawableBlock();
        uint256 counter = 0;
        uint256 shares = 0;
        for (uint256 i = 0; i < indices.length; i++) {
            WithdrawalData storage withdrawal = _withdrawals[indices[i]];
            if (withdrawal.isClaimed) {
                uint256 totalShares = withdrawal.shares;
                uint256 accountShares = withdrawal.sharesOf[account];
                assets += totalShares == accountShares
                    ? withdrawal.assets
                    : withdrawal.assets.mulDiv(accountShares, totalShares);
            } else if (block_ >= withdrawal.data.startBlock && counter < MAX_CLAIMING_WITHDRAWALS) {
                counter++;
                shares += withdrawal.sharesOf[account];
            }
        }
        assets += accountData_.claimableAssets;
        assets += shares == 0 ? 0 : IStrategy(strategy).sharesToUnderlyingView(shares);
    }

    /// @inheritdoc IEigenLayerWithdrawalQueue
    function getAccountData(
        address account,
        uint256 withdrawalsLimit,
        uint256 withdrawalsOffset,
        uint256 transferredWithdrawalsLimit,
        uint256 transferredWithdrawalsOffset
    )
        external
        view
        returns (
            uint256 claimableAssets,
            uint256[] memory withdrawals,
            uint256[] memory transferredWithdrawals
        )
    {
        AccountData storage accountData_ = _accountData[account];
        claimableAssets = accountData_.claimableAssets;
        {
            EnumerableSet.UintSet storage withdrawals_ = accountData_.withdrawals;
            uint256 length = withdrawals_.length();
            if (withdrawalsOffset < length) {
                uint256 count = (length - withdrawalsOffset).min(withdrawalsLimit);
                withdrawals = new uint256[](count);
                for (uint256 i = 0; i < count; i++) {
                    withdrawals[i] = withdrawals_.at(i + withdrawalsOffset);
                }
            }
        }
        {
            EnumerableSet.UintSet storage withdrawals_ = accountData_.transferredWithdrawals;
            uint256 length = withdrawals_.length();
            if (transferredWithdrawalsOffset < length) {
                uint256 count =
                    (length - transferredWithdrawalsOffset).min(transferredWithdrawalsLimit);
                transferredWithdrawals = new uint256[](count);
                for (uint256 i = 0; i < count; i++) {
                    transferredWithdrawals[i] = withdrawals_.at(i + transferredWithdrawalsOffset);
                }
            }
        }
    }

    /// @inheritdoc IEigenLayerWithdrawalQueue
    function getWithdrawalRequest(uint256 index, address account)
        external
        view
        returns (IDelegationManager.Withdrawal memory, bool, uint256, uint256, uint256)
    {
        WithdrawalData storage withdrawal = _withdrawals[index];
        return (
            withdrawal.data,
            withdrawal.isClaimed,
            withdrawal.assets,
            withdrawal.shares,
            withdrawal.sharesOf[account]
        );
    }

    /// --------------- EXTERNAL MUTABLE FUNCTIONS ---------------

    function request(address account, uint256 assets, bool isSelfRequested) public virtual {
        address isolatedVault_ = isolatedVault;
        require(msg.sender == isolatedVault_, "EigenLayerWithdrawalQueue: forbidden");
        handleWithdrawals(account);
        IStrategy[] memory strategies = new IStrategy[](1);
        uint256[] memory shares = new uint256[](1);
        strategies[0] = IStrategy(strategy);
        shares[0] = IStrategy(strategies[0]).underlyingToSharesView(assets);
        if (shares[0] == 0) {
            // nothing to withdraw
            return;
        }
        IDelegationManager delegationManager = IDelegationManager(delegation);

        IDelegationManager.Withdrawal memory data = IDelegationManager.Withdrawal({
            staker: isolatedVault_,
            delegatedTo: operator,
            withdrawer: isolatedVault_,
            nonce: delegationManager.cumulativeWithdrawalsQueued(isolatedVault_),
            startBlock: uint32(block.number),
            strategies: strategies,
            shares: shares
        });

        IDelegationManager.QueuedWithdrawalParams[] memory requests =
            new IDelegationManager.QueuedWithdrawalParams[](1);
        requests[0] = IDelegationManager.QueuedWithdrawalParams(strategies, shares, isolatedVault_);
        IIsolatedEigenLayerVault(isolatedVault_).queueWithdrawals(delegationManager, requests);

        _pushRequest(data, account, isSelfRequested);
    }

    /// @inheritdoc IWithdrawalQueue
    function transferPendingAssets(address to, uint256 amount) public virtual {
        address from = msg.sender;
        if (amount == 0 || from == to) {
            return;
        }
        handleWithdrawals(from);
        AccountData storage accountDataFrom = _accountData[from];
        AccountData storage accountDataTo = _accountData[to];
        uint256 pendingWithdrawals = accountDataFrom.withdrawals.length();
        IStrategy strategy_ = IStrategy(strategy);
        for (uint256 i = 0; i < pendingWithdrawals;) {
            uint256 withdrawalIndex = accountDataFrom.withdrawals.at(i);
            mapping(address => uint256) storage balances = _withdrawals[withdrawalIndex].sharesOf;
            uint256 accountShares;
            uint256 accountAssets;
            {
                WithdrawalData storage withdrawal = _withdrawals[withdrawalIndex];
                accountShares = balances[from];
                accountAssets = withdrawal.isClaimed
                    ? withdrawal.assets.mulDiv(accountShares, withdrawal.shares)
                    : strategy_.sharesToUnderlyingView(accountShares);
            }
            if (accountAssets == 0) {
                i++;
            } else if (accountAssets <= amount) {
                delete balances[from];
                balances[to] += accountShares;
                accountDataFrom.withdrawals.remove(withdrawalIndex);
                amount -= accountAssets;
                pendingWithdrawals--;
                if (!accountDataTo.withdrawals.contains(withdrawalIndex)) {
                    accountDataTo.transferredWithdrawals.add(withdrawalIndex);
                }
                if (amount == 0) {
                    return;
                }
            } else {
                uint256 shares_ = accountShares.mulDiv(amount, accountAssets);
                if (shares_ == 0) {
                    return;
                }
                balances[from] -= shares_;
                balances[to] += shares_;
                if (!accountDataTo.withdrawals.contains(withdrawalIndex)) {
                    accountDataTo.transferredWithdrawals.add(withdrawalIndex);
                }
                return;
            }
        }
        if (amount != 0) {
            _transferClaimableAsPending(accountDataFrom, accountDataTo, amount);
        }
    }

    /// @inheritdoc IWithdrawalQueue
    function pull(uint256 withdrawalIndex) public {
        WithdrawalData storage withdrawal = _withdrawals[withdrawalIndex];
        if (withdrawal.isClaimed) {
            return;
        }
        IDelegationManager.Withdrawal memory data = withdrawal.data;
        if (
            data.startBlock + IDelegationManager(delegation).getWithdrawalDelay(data.strategies)
                <= block.number
        ) {
            _pull(withdrawal);
        }
    }

    /// @inheritdoc IEigenLayerWithdrawalQueue
    function handleWithdrawals(address account) public {
        AccountData storage accountData_ = _accountData[account];
        EnumerableSet.UintSet storage withdrawals_ = accountData_.withdrawals;
        uint256 counter = 0;
        uint256 block_ = latestWithdrawableBlock();
        uint256 length = withdrawals_.length();
        for (uint256 i = 0; i < length;) {
            uint256 index = withdrawals_.at(i);
            WithdrawalData storage withdrawal = _withdrawals[index];
            bool isHandleable = withdrawal.isClaimed;
            if (
                !isHandleable && block_ >= withdrawal.data.startBlock
                    && counter < MAX_CLAIMING_WITHDRAWALS
            ) {
                counter++;
                _pull(withdrawal);
                isHandleable = true;
            }
            if (isHandleable) {
                accountData_.withdrawals.remove(index);
                _handleWithdrawal(index, withdrawal, account, accountData_);
                length--;
            } else {
                i++;
            }
        }
    }

    /// @inheritdoc IWithdrawalQueue
    function claim(address account, address to, uint256 maxAmount)
        external
        returns (uint256 assets)
    {
        address sender = msg.sender;
        require(sender == account || sender == claimer, "EigenLayerWithdrawalQueue: forbidden");
        handleWithdrawals(account);
        AccountData storage accountData_ = _accountData[account];
        assets = maxAmount.min(accountData_.claimableAssets);
        if (assets != 0) {
            accountData_.claimableAssets -= assets;
            IERC20(IIsolatedEigenLayerVault(isolatedVault).asset()).safeTransfer(to, assets);
        }
    }

    /// @inheritdoc IEigenLayerWithdrawalQueue
    function acceptPendingAssets(address account, uint256[] calldata withdrawals_) external {
        address sender = msg.sender;
        require(sender == account || sender == claimer, "EigenLayerWithdrawalQueue: forbidden");
        AccountData storage accountData_ = _accountData[account];
        EnumerableSet.UintSet storage transferredWithdrawals = accountData_.transferredWithdrawals;
        EnumerableSet.UintSet storage withdrawals = accountData_.withdrawals;
        for (uint256 i = 0; i < withdrawals_.length; i++) {
            if (transferredWithdrawals.remove(withdrawals_[i])) {
                withdrawals.add(withdrawals_[i]);
            }
        }
        handleWithdrawals(account);
        require(
            withdrawals.length() <= MAX_PENDING_WITHDRAWALS,
            "EigenLayerWithdrawalQueue: max withdrawal requests reached"
        );
    }

    /// @inheritdoc IEigenLayerWithdrawalQueue
    function shutdown(uint32 blockNumber, uint256 shares) external {
        address isolatedVault_ = isolatedVault;
        IDelegationManager delegationManager = IDelegationManager(delegation);
        require(
            !isShutdown && !delegationManager.isDelegated(isolatedVault_),
            "EigenLayerWithdrawalQueue: not force unstaked yet"
        );

        IDelegationManager.Withdrawal memory withdrawal = IDelegationManager.Withdrawal({
            staker: isolatedVault_,
            delegatedTo: operator,
            withdrawer: isolatedVault_,
            nonce: delegationManager.cumulativeWithdrawalsQueued(isolatedVault_) - 1,
            startBlock: blockNumber,
            strategies: new IStrategy[](1),
            shares: new uint256[](1)
        });
        withdrawal.strategies[0] = IStrategy(strategy);
        withdrawal.shares[0] = shares;

        bytes32 withdrawalRoot = delegationManager.calculateWithdrawalRoot(withdrawal);
        require(
            IDelegationManagerExtended(delegation).pendingWithdrawals(withdrawalRoot),
            "EigenLayerWithdrawalQueue: invalid withdrawal root"
        );

        _pushRequest(withdrawal, IIsolatedEigenLayerVault(isolatedVault_).vault(), true);
        isShutdown = true;
    }

    /// --------------- INTERNAL MUTABLE FUNCTIONS ---------------

    function __init_EigenLayerWithdrawalQueue(
        address isolatedVault_,
        address strategy_,
        address operator_
    ) internal onlyInitializing {
        isolatedVault = isolatedVault_;
        strategy = strategy_;
        operator = operator_;
    }

    function _pushRequest(
        IDelegationManager.Withdrawal memory data,
        address account,
        bool isSelfRequested
    ) internal {
        uint256 withdrawalIndex = _withdrawals.length;
        WithdrawalData storage withdrawal = _withdrawals.push();
        withdrawal.data = data;
        withdrawal.shares = data.shares[0];
        withdrawal.sharesOf[account] = data.shares[0];
        AccountData storage accountData = _accountData[account];
        if (isSelfRequested) {
            if (accountData.withdrawals.length() + 1 > MAX_PENDING_WITHDRAWALS) {
                revert("EigenLayerWithdrawalQueue: max withdrawal requests reached");
            }
            accountData.withdrawals.add(withdrawalIndex);
        } else {
            accountData.transferredWithdrawals.add(withdrawalIndex);
        }
    }

    function _transferClaimableAsPending(
        AccountData storage accountDataFrom,
        AccountData storage accountDataTo,
        uint256 assets
    ) internal virtual {
        if (assets < accountDataFrom.claimableAssets) {
            revert("EigenLayerWithdrawalQueue: insufficient pending assets");
        } else {
            accountDataFrom.claimableAssets -= assets;
            accountDataTo.claimableAssets += assets;
        }
    }

    function _pull(WithdrawalData storage withdrawal) internal virtual {
        withdrawal.assets = IIsolatedEigenLayerVault(isolatedVault).claimWithdrawal(
            IDelegationManager(delegation), withdrawal.data
        );
        withdrawal.isClaimed = true;
    }

    function _handleWithdrawal(
        uint256 withdrawalIndex,
        WithdrawalData storage withdrawal,
        address account,
        AccountData storage accountData_
    ) private {
        uint256 accountShares = withdrawal.sharesOf[account];
        if (accountShares == 0) {
            return;
        }
        uint256 assets = withdrawal.assets;
        uint256 shares = withdrawal.shares;
        delete withdrawal.sharesOf[account];
        if (accountShares == shares) {
            delete _withdrawals[withdrawalIndex];
            accountData_.claimableAssets += assets;
        } else {
            uint256 assets_ = assets.mulDiv(accountShares, shares);
            accountData_.claimableAssets += assets_;
            withdrawal.assets = assets - assets_;
            withdrawal.shares = shares - accountShares;
        }
    }
}
