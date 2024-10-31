// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./MellowEigenLayerVault.sol";
import "./interfaces/utils/IEigenLayerWithdrawalQueue.sol";

contract EigenLayerWithdrawalQueue is IEigenLayerWithdrawalQueue {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    /*
        1. gas cost of each call `IDelegationManager::completeWithdrawal` is ~150-400k gas
        2. gas limit of each block on mainnet is 30M
        3. hard limit for max withdrawal requests is 30 to prevent most of OOG errors.
    */
    uint256 public constant MAX_WITHDRAWAL_REQUESTS = 30;

    address public immutable vault;
    address public immutable claimer;
    address public immutable collateral;

    uint256 public claimableAssets;
    uint256 public pendingShares;
    WithdrawalData[] private _withdrawals;
    mapping(address account => AccountData) private _accountData;

    constructor(address vault_, address asset_, address claimer_) {
        vault = vault_;
        collateral = asset_;
        claimer = claimer_;
    }

    function pendingAssets() public view returns (uint256) {
        return MellowEigenLayerVault(vault).strategy().sharesToUnderlyingView(pendingShares);
    }

    function balancesOf(address account)
        public
        view
        returns (bool[] memory isClaimed, bool[] memory isClaimable, uint256[] memory assets)
    {
        AccountData storage accountData = _accountData[account];
        uint256[] memory indices = accountData.withdrawalIndices.values();
        isClaimed = new bool[](indices.length);
        isClaimable = new bool[](indices.length);
        assets = new uint256[](indices.length);
        for (uint256 i = 0; i < indices.length; i++) {
            (isClaimed[i], isClaimable[i], assets[i],) = withdrawalAssetsOf(indices[i], account);
        }
    }

    function balanceOf(address account) public view returns (uint256 assets) {
        (,, uint256[] memory assets_) = balancesOf(account);
        for (uint256 i = 0; i < assets_.length; i++) {
            assets += assets_[i];
        }
    }

    function pendingAssetsOf(address account) public view returns (uint256 assets) {
        (bool[] memory isClaimed, bool[] memory isClaimable, uint256[] memory assets_) =
            balancesOf(account);
        for (uint256 i = 0; i < assets_.length; i++) {
            if (!isClaimed[i] && isClaimable[i]) {
                assets += assets_[i];
            }
        }
    }

    function claimableAssetsOf(address account) public view returns (uint256 assets) {
        (bool[] memory isClaimed, bool[] memory isClaimable, uint256[] memory assets_) =
            balancesOf(account);
        for (uint256 i = 0; i < assets_.length; i++) {
            if (isClaimed[i] || isClaimable[i]) {
                assets += assets_[i];
            }
        }
    }

    function maxWithdrawalRequests() public view returns (uint256) {
        return MAX_WITHDRAWAL_REQUESTS.min(MellowEigenLayerVault(vault).maxWithdrawalRequests());
    }

    function request(address account, uint256 assets, bool isSelfRequested) external {
        require(msg.sender == vault, "EigenLayerWithdrawalQueue: forbidden");
        handleWithdrawals(account);
        MellowEigenLayerVault vault_ = MellowEigenLayerVault(vault);
        IStrategy[] memory strategies = new IStrategy[](1);
        uint256[] memory shares = new uint256[](1);
        strategies[0] = vault_.strategy();
        shares[0] = strategies[0].underlyingToSharesView(assets);
        IDelegationManager delegationManager = vault_.delegationManager();
        IDelegationManager.Withdrawal memory data = IDelegationManager.Withdrawal({
            staker: vault,
            delegatedTo: vault_.strategyOperator(),
            withdrawer: vault,
            nonce: delegationManager.cumulativeWithdrawalsQueued(vault),
            startBlock: uint32(block.number),
            strategies: strategies,
            shares: shares
        });
        bytes32[] memory roots = vault_.proxyRequestWithdrawals(
            IDelegationManager.QueuedWithdrawalParams({
                strategies: strategies,
                shares: shares,
                withdrawer: vault
            })
        );
        require(
            roots.length == 1 && roots[0] == delegationManager.calculateWithdrawalRoot(data),
            "EigenLayerWithdrawalQueue: withdrawalRoot mismatch"
        );

        pendingShares += shares[0];

        uint256 withdrawalIndex = _withdrawals.length;
        WithdrawalData storage withdrawal = _withdrawals.push();
        withdrawal.data = data;
        withdrawal.totalSupply = assets;
        AccountData storage accountData = _accountData[account];
        if (isSelfRequested) {
            if (accountData.withdrawalIndices.length() + 1 >= maxWithdrawalRequests()) {
                revert("EigenLayerWithdrawalQueue: max withdrawal requests reached");
            }
            accountData.withdrawalIndices.add(withdrawalIndex);
        } else {
            accountData.transferedWithdrawalIndices.add(withdrawalIndex);
        }
        withdrawal.balanceOf[account] += assets;
    }

    function withdrawalAssets(uint256 withdrawalIndex)
        public
        view
        returns (bool isClaimed, bool isClaimable, uint256 assets, uint256 shares)
    {
        WithdrawalData storage withdrawal = _withdrawals[withdrawalIndex];
        if (withdrawal.isClaimed) {
            return (true, false, withdrawal.assets, 0);
        }
        IDelegationManager delegationManager = MellowEigenLayerVault(vault).delegationManager();
        IStrategy strategy = MellowEigenLayerVault(vault).strategy();
        isClaimable = withdrawal.data.startBlock
            + delegationManager.getWithdrawalDelay(withdrawal.data.strategies) <= block.number;
        shares = withdrawal.data.shares[0];
        assets = strategy.sharesToUnderlyingView(shares);
    }

    function withdrawalAssetsOf(uint256 withdrawalIndex, address account)
        public
        view
        returns (bool isClaimed, bool isClaimable, uint256 assets, uint256 shares)
    {
        (isClaimed, isClaimable, assets,) = withdrawalAssets(withdrawalIndex);
        WithdrawalData storage withdrawal = _withdrawals[withdrawalIndex];
        shares = withdrawal.balanceOf[account];
        assets = shares == 0 ? 0 : assets.mulDiv(shares, withdrawal.totalSupply);
    }

    function acceptPendingAssets(address account, uint256[] calldata withdrawalIndices) external {
        address sender = msg.sender;
        require(sender == msg.sender || sender == claimer, "EigenLayerWithdrawalQueue: forbidden");
        handleWithdrawals(account);
        AccountData storage accountData_ = _accountData[account];
        uint256 maxWithdrawalRequests_ = maxWithdrawalRequests();
        uint256 pendingWithdrawals = accountData_.withdrawalIndices.length();
        for (uint256 i = 0; i < withdrawalIndices.length; i++) {
            uint256 withdrawalIndex = withdrawalIndices[i];
            if (accountData_.transferedWithdrawalIndices.remove(withdrawalIndex)) {
                require(
                    pendingWithdrawals < maxWithdrawalRequests_,
                    "EigenLayerWithdrawalQueue: max withdrawal requests reached"
                );
                accountData_.withdrawalIndices.add(withdrawalIndex);
                pendingWithdrawals += 1;
            }
        }
    }

    function transferPendingAssets(address from, address to, uint256 amount) external {
        address sender = msg.sender;
        require(sender == from, "EigenLayerWithdrawalQueue: forbidden");
        handleWithdrawals(from);
        AccountData storage fromData = _accountData[from];
        uint256 pendingWithdrawals = fromData.withdrawalIndices.length();
        for (uint256 i = 0; i < pendingWithdrawals; i++) {
            uint256 withdrawalIndex = fromData.withdrawalIndices.at(i);
            (,, uint256 assets, uint256 shares) = withdrawalAssetsOf(withdrawalIndex, from);
            if (assets == 0) {
                continue;
            }
            uint256 assets_ = assets.min(amount);
            uint256 shares_ = shares.mulDiv(assets_, assets);
            amount -= assets_;
            mapping(address => uint256) storage balances = _withdrawals[withdrawalIndex].balanceOf;
            balances[from] -= shares_;
            balances[to] += shares_;
            _accountData[to].transferedWithdrawalIndices.add(withdrawalIndex);
            if (shares_ == shares) {
                fromData.withdrawalIndices.remove(withdrawalIndex);
            } else {
                break;
            }
        }
        if (amount != 0) {
            revert("EigenLayerWithdrawalQueue: insufficient pending assets");
        }
    }

    function pull(uint256 withdrawalIndex) public {
        _pull(_withdrawals[withdrawalIndex]);
    }

    function _pull(WithdrawalData storage withdrawal) private returns (bool) {
        if (withdrawal.isClaimed) {
            return true;
        }
        IDelegationManager.Withdrawal memory data = withdrawal.data;
        if (
            data.startBlock
                + MellowEigenLayerVault(vault).delegationManager().getWithdrawalDelay(data.strategies)
                <= block.number
        ) {
            withdrawal.assets = MellowEigenLayerVault(vault).proxyClaimWithdrawals(data);
            withdrawal.isClaimed = true;
            return true;
        }
        return false;
    }

    function handleWithdrawals(address account) public {
        AccountData storage accountData_ = _accountData[account];
        uint256[] memory indices = accountData_.withdrawalIndices.values();
        for (uint256 i = 0; i < indices.length; i++) {
            WithdrawalData storage withdrawal = _withdrawals[indices[i]];
            if (!_pull(withdrawal)) {
                continue;
            }
            uint256 balance = withdrawal.balanceOf[account];
            if (balance == 0) {
                continue;
            }
            uint256 assets = withdrawal.assets;
            uint256 totalSupply = withdrawal.totalSupply;
            uint256 assets_ = assets.mulDiv(balance, totalSupply);
            delete withdrawal.balanceOf[account];
            accountData_.claimableAssets += assets_;
            withdrawal.assets -= assets_;
            withdrawal.totalSupply -= balance;
            accountData_.withdrawalIndices.remove(indices[i]);
            accountData_.transferedWithdrawalIndices.remove(indices[i]);
        }
    }

    function claim(address account, address recipient, uint256 maxAmount)
        external
        returns (uint256 assets)
    {
        address sender = msg.sender;
        require(
            sender == account || sender == vault || sender == claimer,
            "EigenLayerWithdrawalQueue: forbidden"
        );
        handleWithdrawals(account);
        AccountData storage accountData_ = _accountData[account];
        assets = maxAmount.min(accountData_.claimableAssets);
        if (assets != 0) {
            accountData_.claimableAssets -= assets;
            IERC20(collateral).safeTransfer(recipient, assets);
        }
    }
}
