// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/queues/IEigenLayerWithdrawalQueue.sol";

/**
 * @title EigenLayerWithdrawalQueue
 * @notice Manages the withdrawal requests and claims for isolated EigenLayer vaults.
 * @dev Implements the `IEigenLayerWithdrawalQueue` interface, providing functionality for tracking and processing withdrawals.
 */
contract EigenLayerWithdrawalQueue is IEigenLayerWithdrawalQueue, Initializable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 public constant MAX_PENDING_WITHDRAWALS = 50;
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

    WithdrawalData[] private _withdrawals;
    mapping(address account => AccountData) private _accountData;

    constructor(address claimer_, address delegation_) {
        claimer = claimer_;
        delegation = delegation_;
        _disableInitializers();
    }

    /**
     * @notice Initializes the withdrawal queue for a specific isolated vault.
     * @dev Can only be called once during the lifetime of the contract.
     * @param isolatedVault_ Address of the isolated vault.
     * @param strategy_ Address of the strategy associated with the vault.
     * @param operator_ Address of the operator managing the vault.
     */
    function initialize(address isolatedVault_, address strategy_, address operator_)
        external
        initializer
    {
        __init_EigenLayerWithdrawalQueue(isolatedVault_, strategy_, operator_);
    }

    /**
     * @notice Internal function to set up the withdrawal queue.
     * @param isolatedVault_ Address of the isolated vault.
     * @param strategy_ Address of the strategy associated with the vault.
     * @param operator_ Address of the operator managing the vault.
     */
    function __init_EigenLayerWithdrawalQueue(
        address isolatedVault_,
        address strategy_,
        address operator_
    ) internal onlyInitializing {
        isolatedVault = isolatedVault_;
        strategy = strategy_;
        operator = operator_;
    }

    /// --------------- EXTERNAL VIEW FUNCTIONS ---------------

    /// @inheritdoc IEigenLayerWithdrawalQueue
    function latestWithdrawableBlock() public view returns (uint256) {
        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = IStrategy(strategy);
        return block.number - IDelegationManager(delegation).getWithdrawalDelay(strategies);
    }

    /// @inheritdoc IWithdrawalQueue
    function pendingAssetsOf(address account) public view returns (uint256 assets) {
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
    function claimableAssetsOf(address account) public view returns (uint256 assets) {
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
                    : Math.mulDiv(withdrawal.assets, accountShares, totalShares);
            } else if (block_ >= withdrawal.data.startBlock && counter < MAX_CLAIMING_WITHDRAWALS) {
                counter++;
                shares += withdrawal.sharesOf[account];
            }
        }
        assets += shares == 0 ? 0 : IStrategy(strategy).sharesToUnderlyingView(shares);
    }
    /**
     * @notice Retrieves transferred withdrawals for a specific account.
     * @param account Address of the account to query.
     * @param limit Maximum number of results to return.
     * @param offset Number of withdrawals to skip.
     * @return withdrawals Array of withdrawal indices.
     */

    function transferedWithdrawalsOf(address account, uint256 limit, uint256 offset)
        public
        view
        returns (uint256[] memory withdrawals)
    {
        AccountData storage accountData_ = _accountData[account];
        EnumerableSet.UintSet storage transferedWithdrawals = accountData_.transferedWithdrawals;
        uint256 length = transferedWithdrawals.length();
        if (offset >= length) {
            return withdrawals;
        }
        uint256 count = (length - offset).min(limit);
        for (uint256 i = 0; i < count; i++) {
            withdrawals[i] = transferedWithdrawals.at(i + offset);
        }
    }

    /// --------------- EXTERNAL MUTABLE FUNCTIONS ---------------

    /// @inheritdoc IEigenLayerWithdrawalQueue
    function request(address account, uint256 assets, bool isSelfRequested) external {
        address isolatedVault_ = isolatedVault;
        require(msg.sender == isolatedVault_, "EigenLayerWithdrawalQueue: forbidden");
        handleWithdrawals(account);
        IStrategy[] memory strategies = new IStrategy[](1);
        uint256[] memory shares = new uint256[](1);
        strategies[0] = IStrategy(strategy);
        shares[0] = IStrategy(strategies[0]).underlyingToSharesView(assets);
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

        uint256 withdrawalIndex = _withdrawals.length;
        WithdrawalData storage withdrawal = _withdrawals.push();
        withdrawal.data = data;
        withdrawal.assets = assets;
        withdrawal.shares = shares[0];
        withdrawal.sharesOf[account] = shares[0];
        AccountData storage accountData = _accountData[account];
        if (isSelfRequested) {
            if (accountData.withdrawals.length() + 1 > MAX_PENDING_WITHDRAWALS) {
                revert("EigenLayerWithdrawalQueue: max withdrawal requests reached");
            }
            accountData.withdrawals.add(withdrawalIndex);
        } else {
            accountData.transferedWithdrawals.add(withdrawalIndex);
        }
    }

    /// @inheritdoc IWithdrawalQueue
    function transferPendingAssets(address to, uint256 amount) external {
        address from = msg.sender;
        if (amount == 0 || from == to) {
            return;
        }
        handleWithdrawals(from);
        AccountData storage accountData_ = _accountData[from];
        uint256 pendingWithdrawals = accountData_.withdrawals.length();
        IStrategy strategy_ = IStrategy(strategy);
        for (uint256 i = 0; i < pendingWithdrawals;) {
            uint256 withdrawalIndex = accountData_.withdrawals.at(i);
            WithdrawalData storage withdrawal = _withdrawals[withdrawalIndex];
            uint256 accountShares = withdrawal.sharesOf[from];
            uint256 accountAssets = withdrawal.isClaimed
                ? Math.mulDiv(withdrawal.assets, accountShares, withdrawal.shares)
                : strategy_.sharesToUnderlyingView(accountShares);
            if (accountAssets == 0) {
                i++;
                continue;
            }
            _accountData[to].transferedWithdrawals.add(withdrawalIndex);
            mapping(address => uint256) storage balances = withdrawal.sharesOf;
            if (accountAssets <= amount) {
                delete balances[from];
                balances[to] += accountShares;
                accountData_.withdrawals.remove(withdrawalIndex);
                amount -= accountAssets;
                pendingWithdrawals--;
            } else {
                uint256 shares_ = accountShares.mulDiv(amount, accountAssets);
                balances[from] -= shares_;
                balances[to] += shares_;
                return;
            }
        }
        if (amount != 0) {
            revert("EigenLayerWithdrawalQueue: insufficient pending assets");
        }
    }

    /// @inheritdoc IWithdrawalQueue
    function pull(uint256 withdrawalIndex) public {
        _pull(_withdrawals[withdrawalIndex]);
    }

    /// @inheritdoc IEigenLayerWithdrawalQueue
    function handleWithdrawals(address account) public {
        AccountData storage accountData_ = _accountData[account];
        uint256[] memory indices = accountData_.withdrawals.values();
        uint256 counter = 0;
        uint256 block_ = latestWithdrawableBlock();
        for (uint256 i = 0; i < indices.length; i++) {
            uint256 withdrawalIndex = indices[i];
            WithdrawalData storage withdrawal = _withdrawals[withdrawalIndex];
            if (withdrawal.isClaimed) {
                _handleWithdrawal(withdrawalIndex, withdrawal, account, accountData_);
            } else if (block_ >= withdrawal.data.startBlock && counter < MAX_CLAIMING_WITHDRAWALS) {
                counter++;
                _pull(withdrawal);
                _handleWithdrawal(withdrawalIndex, withdrawal, account, accountData_);
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
        EnumerableSet.UintSet storage transferedWithdrawals = accountData_.transferedWithdrawals;
        EnumerableSet.UintSet storage withdrawals = accountData_.withdrawals;
        for (uint256 i = 0; i < withdrawals_.length; i++) {
            if (transferedWithdrawals.remove(withdrawals_[i])) {
                withdrawals.add(withdrawals_[i]);
            }
        }
        handleWithdrawals(account);
        require(
            withdrawals.length() <= MAX_PENDING_WITHDRAWALS,
            "EigenLayerWithdrawalQueue: max withdrawal requests reached"
        );
    }

    /// --------------- INTERNAL MUTABLE FUNCTIONS ---------------

    /**
     * @notice Internal function to process and pull a withdrawal.
     * @param withdrawal The withdrawal data to process.
     * @return True if the withdrawal was successfully claimed, false otherwise.
     */
    function _pull(WithdrawalData storage withdrawal) private returns (bool) {
        if (withdrawal.isClaimed) {
            return true;
        }
        IDelegationManager.Withdrawal memory data = withdrawal.data;
        if (
            data.startBlock + IDelegationManager(delegation).getWithdrawalDelay(data.strategies)
                <= block.number
        ) {
            withdrawal.assets = IIsolatedEigenLayerVault(isolatedVault).claimWithdrawal(
                IDelegationManager(delegation), data
            );
            withdrawal.isClaimed = true;
            return true;
        }
        return false;
    }

    /**
     * @notice Internal function to handle an account's withdrawal.
     * @param withdrawalIndex Index of the withdrawal in the global array.
     * @param withdrawal The withdrawal data to process.
     * @param account Address of the account associated with the withdrawal.
     * @param accountData_ The account's specific data structure.
     */
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
        if (accountShares == shares) {
            delete _withdrawals[withdrawalIndex];
            accountData_.claimableAssets += assets;
        } else {
            delete withdrawal.sharesOf[account];
            uint256 assets_ = assets.mulDiv(accountShares, shares);
            accountData_.claimableAssets += assets_;
            withdrawal.assets = assets - assets_;
            withdrawal.shares = shares - accountShares;
        }
        accountData_.withdrawals.remove(withdrawalIndex);
        accountData_.transferedWithdrawals.remove(withdrawalIndex);
    }
}
