// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import "./ERC1271.sol";
import {ERC4626Vault} from "./ERC4626Vault.sol";
import {VaultControl, VaultControlStorage} from "./VaultControl.sol";
import "./interfaces/vaults/IMellowEigenLayerVault.sol";

contract MellowEigenLayerVault is IMellowEigenLayerVault, ERC4626Vault, ERC1271 {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 private nonce;
    address public strategy;
    address public operator;
    address public delegationManager;
    address public strategyManager;

    mapping(address account => IDelegationManager.Withdrawal[] data) private _withdrawals;

    constructor(bytes32 contractName_, uint256 contractVersion_)
        VaultControlStorage(contractName_, contractVersion_)
    {}

    function initialize(InitParams memory initParams) public virtual initializer {
        __initialize(initParams);
    }

    function __initialize(InitParams memory initParams) internal virtual onlyInitializing {
        DelegationParam memory delegationParam = initParams.delegationParam;
        delegationManager = delegationParam.delegationManager;
        strategyManager = delegationParam.strategyManager;
        strategy = delegationParam.strategy;
        operator = delegationParam.operator;
        uint256 expiry = block.timestamp + delegationParam.expiry;

        address delegationApprover =
            IDelegationManager(delegationManager).delegationApprover(delegationParam.operator);
        IDelegationManager(delegationParam.delegationManager).calculateDelegationApprovalDigestHash(
            address(this),
            delegationParam.operator,
            delegationApprover,
            delegationParam.salt,
            expiry
        );
        ISignatureUtils.SignatureWithExpiry memory signatureWithExpiry =
            ISignatureUtils.SignatureWithExpiry(delegationParam.delegationSignature, expiry);

        IDelegationManager(delegationManager).delegateTo(
            delegationParam.operator, signatureWithExpiry, delegationParam.salt
        );

        address underlyingToken = address(IStrategy(strategy).underlyingToken());

        __initializeERC4626(
            initParams.admin,
            initParams.limit,
            initParams.depositPause,
            initParams.withdrawalPause,
            initParams.depositWhitelist,
            underlyingToken,
            initParams.name,
            initParams.symbol
        );
    }

    // ERC4626 overrides
    function totalAssets()
        public
        view
        virtual
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256)
    {
        return IERC20(asset()).balanceOf(address(this))
            + IStrategy(strategy).userUnderlyingView(address(this));
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        virtual
        override
    {
        super._deposit(caller, receiver, assets, shares);

        IERC20(asset()).approve(strategyManager, assets);

        uint256 actualShares = IStrategyManager(strategyManager).depositIntoStrategy(
            IStrategy(strategy), IERC20(asset()), assets
        );

        require(actualShares >= shares, "Vault: insufficient shares");

        emit EigenLayerDeposited(caller, assets);
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        require(!withdrawalPause(), "Vault: withdrawal paused");
        address this_ = address(this);

        uint256 liquid = IERC20(asset()).balanceOf(this_);
        if (liquid >= assets) {
            return super._withdraw(caller, receiver, owner, assets, shares);
        }

        uint256 staked = assets - liquid;

        _pushToWithdrawalQueue(receiver, staked);

        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        _burn(owner, shares);
        if (liquid != 0) {
            IERC20(asset()).safeTransfer(receiver, liquid);
        }

        // emitting event with transfered + new pending assets
        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    function _pushToWithdrawalQueue(address account, uint256 stakedAssets) internal {

        uint256 stakedShares = previewWithdraw(stakedAssets);

        bytes32[] memory withdrawalRoots = IDelegationManager(delegationManager).queueWithdrawals(
            _getQueuedWithdrawalParams(stakedShares)
        );

        IDelegationManager.Withdrawal memory withdrawalData = IDelegationManager.Withdrawal({
            staker: address(this),
            delegatedTo: operator,
            withdrawer: address(this),
            nonce: nonce,
            startBlock: uint32(block.number),
            strategies: new IStrategy[](1),
            shares: new uint256[](1)
        });

        withdrawalData.strategies[0] = IStrategy(strategy);
        withdrawalData.shares[0] = stakedShares;

        bytes32 withdrawalRoot =
            IDelegationManager(delegationManager).calculateWithdrawalRoot(withdrawalData);
        require(withdrawalRoots[0] == withdrawalRoot, "Vault: withdrawalRoot mismatch");


        _withdrawals[account].push(withdrawalData);

        nonce += 1;
    }

    function _getQueuedWithdrawalParams(uint256 shares)
        internal
        view
        returns (IDelegationManager.QueuedWithdrawalParams[] memory queuedWithdrawalParams)
    {
        IDelegationManager.QueuedWithdrawalParams memory queuedWithdrawalParam = IDelegationManager
            .QueuedWithdrawalParams({
            strategies: new IStrategy[](1),
            shares: new uint256[](1),
            withdrawer: address(this)
        });

        queuedWithdrawalParam.strategies[0] = IStrategy(strategy);
        queuedWithdrawalParam.shares[0] = shares;
        queuedWithdrawalParam.withdrawer = address(this);

        queuedWithdrawalParams = new IDelegationManager.QueuedWithdrawalParams[](1);
        queuedWithdrawalParams[0] = queuedWithdrawalParam;
    }

    function claim(address account, address recipient)
        external
        virtual
        nonReentrant
        returns (uint256 claimedAmount)
    {
        address sender = msg.sender;
        require(sender == account || sender == address(this), "Vault: forbidden");

        IDelegationManager.Withdrawal[] memory withdrawalData = _withdrawals[account];
        require(withdrawalData.length > 0, "Vault: no active withdrawals");

        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(asset());
        uint256 minWithdrawalDelayBlocks =
            IDelegationManager(delegationManager).minWithdrawalDelayBlocks();
        uint256 claimed;

        uint256 balanceBefore = IERC20(asset()).balanceOf(address(this));
        for (uint256 i = 0; i < withdrawalData.length; i++) {
            if (withdrawalData[i].startBlock + minWithdrawalDelayBlocks <= block.number) {
                IDelegationManager(delegationManager).completeQueuedWithdrawal(
                    withdrawalData[i], tokens, 0, true
                );
                delete _withdrawals[account][i];
                claimed += 1;
            }
        }
        require(claimed > 0, "Vault: nothing to claim");
        uint256 balanceAfter = IERC20(asset()).balanceOf(address(this));

        if (claimed == withdrawalData.length) {
            delete _withdrawals[account];
        }

        claimedAmount = balanceAfter - balanceBefore;

        if (claimedAmount > 0) {
            IERC20(asset()).transfer(recipient, claimedAmount);
        }

        emit Claimed(account, recipient, claimedAmount);
    }

    /**
     * @dev Internal conversion function (from assets to shares) with support for rounding direction.
     */
    function _convertToShares(uint256 assets, Math.Rounding rounding)
        internal
        view
        override
        returns (uint256 shares)
    {
        shares = IStrategy(strategy).underlyingToSharesView(assets);

        if (shares > 0 && rounding == Math.Rounding.Floor) {
            shares -= 1;
        } else if (rounding == Math.Rounding.Ceil) {
            shares += 1;
        }
    }

    /**
     * @dev Internal conversion function (from shares to assets) with support for rounding direction.
     */
    function _convertToAssets(uint256 shares, Math.Rounding rounding)
        internal
        view
        override
        returns (uint256 assets)
    {
        assets = IStrategy(strategy).sharesToUnderlyingView(shares);

        if (assets > 0 && rounding == Math.Rounding.Floor) {
            assets -= 1;
        } else if (rounding == Math.Rounding.Ceil) {
            assets += 1;
        }
    }

    /// @notice Internal function used to fetch this contract's current balance of `underlyingToken`.
    // slither-disable-next-line dead-code
    function _tokenBalance() internal view virtual returns (uint256) {
        return IERC20(asset()).balanceOf(strategy);
    }
}
