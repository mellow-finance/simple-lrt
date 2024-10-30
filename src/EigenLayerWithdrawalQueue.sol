// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import "./MellowEigenLayerVault.sol";

contract EigenLayerWithdrawalQueue {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

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

    function balanceOf(address account) public view returns (uint256 assets) {
        AccountData storage accountData = _accountData[account];
        assets = accountData.claimableAssets;
        uint256[] memory indices = accountData.withdrawalIndices.values();
        for (uint256 i = 0; i < indices.length; i++) {
            (,, uint256 assets_) = withdrawalAssetsOf(indices[i], account);
            assets += assets_;
        }
    }

    function pendingAssetsOf(address account) public view returns (uint256 assets) {
        AccountData storage accountData = _accountData[account];
        uint256[] memory indices = accountData.withdrawalIndices.values();
        for (uint256 i = 0; i < indices.length; i++) {
            (bool isClaimed, bool isClaimable, uint256 assets_) =
                withdrawalAssetsOf(indices[i], account);
            if (!isClaimed && !isClaimable) {
                assets += assets_;
            }
        }
    }

    function claimableAssetsOf(address account) public view returns (uint256 assets) {
        AccountData storage accountData = _accountData[account];
        assets = accountData.claimableAssets;
        uint256[] memory indices = accountData.withdrawalIndices.values();
        for (uint256 i = 0; i < indices.length; i++) {
            (bool isClaimed, bool isClaimable, uint256 assets_) =
                withdrawalAssetsOf(indices[i], account);
            if (isClaimed || isClaimable) {
                assets += assets_;
            }
        }
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
            uint256 maxWithdrawalRequests =
                MAX_WITHDRAWAL_REQUESTS.min(vault_.maxWithdrawalRequests());
            if (accountData.withdrawalIndices.length() + 1 >= maxWithdrawalRequests) {
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
        returns (bool isClaimed, bool isClaimable, uint256 assets)
    {
        WithdrawalData storage withdrawal = _withdrawals[withdrawalIndex];
        if (withdrawal.isClaimed) {
            return (true, false, withdrawal.assets);
        }
        IDelegationManager delegationManager = MellowEigenLayerVault(vault).delegationManager();
        IStrategy strategy = MellowEigenLayerVault(vault).strategy();
        isClaimable = withdrawal.data.startBlock
            + delegationManager.getWithdrawalDelay(withdrawal.data.strategies) <= block.number;
        assets = strategy.sharesToUnderlyingView(withdrawal.data.shares[0]);
    }

    function withdrawalAssetsOf(uint256 withdrawalIndex, address account)
        public
        view
        returns (bool isClaimed, bool isClaimable, uint256 assets)
    {
        (isClaimed, isClaimable, assets) = withdrawalAssets(withdrawalIndex);
        WithdrawalData storage withdrawal = _withdrawals[withdrawalIndex];
        uint256 balance = withdrawal.balanceOf[account];
        assets = balance == 0 ? 0 : assets.mulDiv(balance, withdrawal.totalSupply);
    }

    function transferPendingAssets(address from, address to, uint256 amount) external {
        // address sender = msg.sender;
        // require(sender == from || sender == vault, "EigenLayerWithdrawalQueue: forbidden");
        // handleWithdrawals(from);
        // AccountData storage fromData = _accountData[from];
        // uint256 pendingWithdrawals = fromData.withdrawalIndices.length();
        // for (uint256 i = 0; i < pendingWithdrawals; i++) {
        //     uint256 withdrawalIndex = fromData.withdrawalIndices.at(i);
        //     (,, uint256 assets) = withdrawalAssetsOf(withdrawalIndex, from);
        //     if (assets == 0) {
        //         continue;
        //     }
        //     uint256 userShares = _withdrawals[withdrawalIndex].balanceOf[from];
        //     uint256 assets_ = assets.min(amount);
        //     uint256 shares = MellowEigenLayerVault(vault).strategy().underlyingToSharesView(assets_);
        // }
    }

    function pull(uint256 withdrawalIndex) public {
        WithdrawalData storage withdrawal = _withdrawals[withdrawalIndex];
        if (withdrawal.isClaimed) {
            return;
        }
        IDelegationManager.Withdrawal memory data = withdrawal.data;
        uint256 firstClaimableBlock = data.startBlock
            + MellowEigenLayerVault(vault).delegationManager().getWithdrawalDelay(data.strategies);
        if (firstClaimableBlock > block.number) {
            return;
        }
        withdrawal.assets = MellowEigenLayerVault(vault).proxyClaimWithdrawals(data);
        withdrawal.isClaimed = true;
    }

    function handleWithdrawals(address account) public {
        AccountData storage accountData_ = _accountData[account];
        uint256[] memory indices = accountData_.withdrawalIndices.values();
        for (uint256 i = 0; i < indices.length; i++) {
            pull(indices[i]);
            WithdrawalData storage withdrawalData_ = _withdrawals[indices[i]];
            if (!withdrawalData_.isClaimed) {
                continue;
            }
            uint256 balance = withdrawalData_.balanceOf[account];
            if (balance == 0) {
                continue;
            }
            uint256 assets = withdrawalData_.assets;
            uint256 totalSupply = withdrawalData_.totalSupply;
            uint256 assets_ = assets.mulDiv(balance, totalSupply);
            delete withdrawalData_.balanceOf[account];
            accountData_.claimableAssets += assets_;
            withdrawalData_.assets -= assets_;
            withdrawalData_.totalSupply -= balance;
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
