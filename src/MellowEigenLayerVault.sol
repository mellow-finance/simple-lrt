// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import "./ERC1271.sol";
import {ERC4626Vault} from "./ERC4626Vault.sol";
import {VaultControl, VaultControlStorage} from "./VaultControl.sol";

import {MellowSymbioticVaultStorage} from "./MellowSymbioticVaultStorage.sol";

import "./interfaces/vaults/IMellowEigenLayerVault.sol";
import "./MellowEigenLayerVaultStorage.sol";

contract MellowEigenLayerVault is IMellowEigenLayerVault, MellowEigenLayerVaultStorage, ERC4626Vault, ERC1271 {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 private nonce;

    mapping(address account => IDelegationManager.Withdrawal[] data) private _withdrawals;

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

        address underlyingToken = address(IStrategy(eigenLayerStorageParam.strategy).underlyingToken());
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

        IDelegationManager(eigenLayerStorageParam.delegationManager).calculateDelegationApprovalDigestHash(
            address(this),
            eigenLayerStorageParam.operator,
            delegationApprover,
            eigenLayerParam.salt,
            eigenLayerParam.expiry
        );

        ISignatureUtils.SignatureWithExpiry memory signatureWithExpiry =
            ISignatureUtils.SignatureWithExpiry(eigenLayerParam.delegationSignature, eigenLayerParam.expiry);

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

        IERC20(asset()).approve(address(eigenLayerStrategyManager()), assets);

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

        bytes32[] memory withdrawalRoots = eigenLayerDelegationManager().queueWithdrawals(
            _getQueuedWithdrawalParams(stakedShares)
        );

        IDelegationManager.Withdrawal memory withdrawalData = IDelegationManager.Withdrawal({
            staker: address(this),
            delegatedTo: eigenLayerStrategyOperator(),
            withdrawer: address(this),
            nonce: nonce,
            startBlock: uint32(block.number),
            strategies: new IStrategy[](1),
            shares: new uint256[](1)
        });

        withdrawalData.strategies[0] = eigenLayerStrategy();
        withdrawalData.shares[0] = stakedShares;

        bytes32 withdrawalRoot =
            eigenLayerDelegationManager().calculateWithdrawalRoot(withdrawalData);
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

        queuedWithdrawalParam.strategies[0] = eigenLayerStrategy();
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
            eigenLayerDelegationManager().minWithdrawalDelayBlocks();
        uint256 claimed;

        uint256 balanceBefore = IERC20(asset()).balanceOf(address(this));
        uint256 eigenLayerClaimWithdrawalsMax = eigenLayerClaimWithdrawalsMax();

        for (uint256 i = 0; i < withdrawalData.length; i++) {
            if (withdrawalData[i].startBlock + minWithdrawalDelayBlocks <= block.number) {
                eigenLayerDelegationManager().completeQueuedWithdrawal(
                    withdrawalData[i], tokens, 0, true
                );
                delete _withdrawals[account][i];
                claimed += 1;
            }
            if (claimed >= eigenLayerClaimWithdrawalsMax) {
                break;
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
        shares = eigenLayerStrategy().underlyingToSharesView(assets);

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
        assets = eigenLayerStrategy().sharesToUnderlyingView(shares);

        if (assets > 0 && rounding == Math.Rounding.Floor) {
            assets -= 1;
        } else if (rounding == Math.Rounding.Ceil) {
            assets += 1;
        }
    }
}
