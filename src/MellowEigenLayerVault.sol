// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import "./ERC1271.sol";
import {ERC4626Vault} from "./ERC4626Vault.sol";
import {VaultControl, VaultControlStorage} from "./VaultControl.sol";

import {MellowSymbioticVaultStorage} from "./MellowSymbioticVaultStorage.sol";

import "./MellowEigenLayerVaultStorage.sol";
import "./interfaces/vaults/IMellowEigenLayerVault.sol";

contract MellowEigenLayerVault is
    IMellowEigenLayerVault,
    MellowEigenLayerVaultStorage,
    ERC4626Vault,
    ERC1271
{
    using SafeERC20 for IERC20;
    using Math for uint256;

    constructor(bytes32 contractName_, uint256 contractVersion_)
        MellowEigenLayerVaultStorage(contractName_, contractVersion_)
        VaultControlStorage(contractName_, contractVersion_)
    {}

    function initialize(InitParams memory initParams) public virtual initializer {
        __initialize(initParams);
    }

    function __initialize(InitParams memory initParams) internal virtual onlyInitializing {
        EigenLayerParam memory eigenLayerParam = initParams.eigenLayerParam;
        EigenLayerStorage memory eigenLayerStorageParam = eigenLayerParam.storageParam;

        address underlyingToken =
            address(IStrategy(eigenLayerStorageParam.strategy).underlyingToken());
        __initializeMellowEigenLayerVaultStorage(eigenLayerStorageParam);
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

        address delegationApprover =
            eigenLayerDelegationManager().delegationApprover(eigenLayerStorageParam.operator);

        IDelegationManager(eigenLayerStorageParam.delegationManager)
            .calculateDelegationApprovalDigestHash(
            address(this),
            eigenLayerStorageParam.operator,
            delegationApprover,
            eigenLayerParam.salt,
            eigenLayerParam.expiry
        );

        ISignatureUtils.SignatureWithExpiry memory signatureWithExpiry = ISignatureUtils
            .SignatureWithExpiry(eigenLayerParam.delegationSignature, eigenLayerParam.expiry);

        eigenLayerDelegationManager().delegateTo(
            eigenLayerStorageParam.operator, signatureWithExpiry, eigenLayerParam.salt
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
            + eigenLayerStrategy().userUnderlyingView(address(this));
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        virtual
        override
    {
        super._deposit(caller, receiver, assets, shares);

        IERC20(asset()).safeIncreaseAllowance(address(eigenLayerStrategyManager()), assets);

        uint256 actualShares = eigenLayerStrategyManager().depositIntoStrategy(
            eigenLayerStrategy(), IERC20(asset()), assets
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

        bytes32[] memory withdrawalRoots =
            eigenLayerDelegationManager().queueWithdrawals(_getQueuedWithdrawalParams(stakedShares));

        IDelegationManager.Withdrawal memory withdrawalData = IDelegationManager.Withdrawal({
            staker: address(this),
            delegatedTo: eigenLayerStrategyOperator(),
            withdrawer: address(this),
            nonce: eigenLayerNonce(),
            startBlock: uint32(block.number),
            strategies: new IStrategy[](1),
            shares: new uint256[](1)
        });

        withdrawalData.strategies[0] = eigenLayerStrategy();
        withdrawalData.shares[0] = stakedShares;

        bytes32 withdrawalRoot =
            eigenLayerDelegationManager().calculateWithdrawalRoot(withdrawalData);
        require(withdrawalRoots[0] == withdrawalRoot, "Vault: withdrawalRoot mismatch");

        mapping(address account => IDelegationManager.Withdrawal[]) storage withdrawals =
            _getEigenLayerWithdrawalQueue();
        withdrawals[account].push(withdrawalData);

        _increaseEigenLayerNonce();
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

        queuedWithdrawalParam.strategies[0] = eigenLayerStrategy();
        queuedWithdrawalParam.shares[0] = shares;

        queuedWithdrawalParams = new IDelegationManager.QueuedWithdrawalParams[](1);
        queuedWithdrawalParams[0] = queuedWithdrawalParam;
    }

    function claim(address account, address recipient)
        external
        virtual
        nonReentrant
        returns (uint256 claimedAmount)
    {
        uint256 eigenLayerClaimWithdrawalsMax = eigenLayerClaimWithdrawalsMax();
        return _claim(account, recipient, eigenLayerClaimWithdrawalsMax);
    }

    function claim(address account, address recipient, uint256 maxWithdrawals)
        external
        virtual
        nonReentrant
        returns (uint256 claimedAmount)
    {
        return _claim(account, recipient, maxWithdrawals);
    }

    function _claim(address account, address recipient, uint256 maxWithdrawals)
        internal
        returns (uint256 claimedAmount)
    {
        address sender = msg.sender;
        require(sender == account || sender == address(this), "Vault: forbidden");

        mapping(address account => IDelegationManager.Withdrawal[]) storage withdrawals =
            _getEigenLayerWithdrawalQueue();
        IDelegationManager.Withdrawal[] storage withdrawalData = withdrawals[account];

        require(withdrawalData.length > 0, "Vault: no active withdrawals");

        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(asset());
        uint256 minWithdrawalDelayBlocks = eigenLayerDelegationManager().minWithdrawalDelayBlocks();
        uint256 claimed;

        uint256 balanceBefore = IERC20(asset()).balanceOf(address(this));

        for (uint256 i = 0; i < withdrawalData.length; i++) {
            if (withdrawalData[i].startBlock + minWithdrawalDelayBlocks <= block.number) {
                eigenLayerDelegationManager().completeQueuedWithdrawal(
                    withdrawalData[i], tokens, 0, true
                );
                delete withdrawalData[i];
                claimed += 1;
            }
            if (claimed >= maxWithdrawals) {
                break;
            }
        }
        require(claimed > 0, "Vault: nothing to claim");
        uint256 balanceAfter = IERC20(asset()).balanceOf(address(this));

        if (claimed == withdrawalData.length) {
            delete withdrawals[account];
        }

        claimedAmount = balanceAfter - balanceBefore;

        if (claimedAmount > 0) {
            IERC20(asset()).safeTransfer(recipient, claimedAmount);
        }

        emit Claimed(account, recipient, claimedAmount);
    }

    function pendingAssetsOf(address account) public view returns (uint256 assets) {
        return _assetsOf(account, true);
    }

    function claimableAssetsOf(address account) public view returns (uint256 assets) {
        return _assetsOf(account, false);
    }

    function _assetsOf(address account, bool up) internal view returns (uint256 assets) {
        mapping(address account => IDelegationManager.Withdrawal[]) storage withdrawals =
            _getEigenLayerWithdrawalQueue();

        uint256 _block = block.number - eigenLayerDelegationManager().minWithdrawalDelayBlocks();

        IDelegationManager.Withdrawal memory withdrawal;
        uint256 shares;

        for (uint256 i = 0; i < withdrawals[account].length; i++) {
            withdrawal = withdrawals[account][i];
            if (up) {
                if (withdrawal.startBlock > _block) {
                    shares += withdrawal.shares[0];
                }
            } else {
                if (withdrawal.startBlock <= _block) {
                    shares += withdrawal.shares[0];
                }
            }
        }

        assets = eigenLayerStrategy().sharesToUnderlyingView(shares);
    }

    /**
     * @dev Internal conversion function (from assets to shares) with support for rounding direction.
     */
    function _convertToShares(uint256 assets, Math.Rounding)
        internal
        view
        override
        returns (uint256 shares)
    {
        shares = eigenLayerStrategy().underlyingToSharesView(assets);
    }

    /**
     * @dev Internal conversion function (from shares to assets) with support for rounding direction.
     */
    function _convertToAssets(uint256 shares, Math.Rounding)
        internal
        view
        override
        returns (uint256 assets)
    {
        assets = eigenLayerStrategy().sharesToUnderlyingView(shares);
    }

    // helper functions

    function getBalances(address account)
        public
        view
        returns (
            uint256 accountAssets,
            uint256 accountInstantAssets,
            uint256 accountShares,
            uint256 accountInstantShares
        )
    {
        uint256 instantAssets = IERC20(asset()).balanceOf(address(this));
        accountShares = balanceOf(account);
        accountAssets = convertToAssets(accountShares);
        accountInstantAssets = accountAssets.min(instantAssets);
        accountInstantShares = convertToShares(accountInstantAssets);
    }
}
