// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {ERC4626Vault} from "./ERC4626Vault.sol";
import {VaultControl, VaultControlStorage} from "./VaultControl.sol";

import {MellowSymbioticVaultStorage} from "./MellowSymbioticVaultStorage.sol";

import "./MellowEigenLayerVaultStorage.sol";
import "./interfaces/vaults/IMellowEigenLayerVault.sol";

contract MellowEigenLayerVault is
    IMellowEigenLayerVault,
    MellowEigenLayerVaultStorage,
    ERC4626Vault
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

    function isValidSignature(bytes32 hash_, bytes memory signature)
        external
        view
        returns (bytes4 magicValue)
    {
        if (_signedHashes[hash_]) {
            bytes32 signatureHash = abi.decode(signature, (bytes32));
            require(
                signatureHash == keccak256(abi.encode(address(this), block.timestamp, hash_)),
                "ERC1271: wrong signature"
            );
            return bytes4(keccak256("isValidSignature(bytes32,bytes)"));
        } else {
            return 0xffffffff;
        }
    }

    function __initialize(InitParams memory initParams) internal virtual onlyInitializing {
        EigenLayerParam memory eigenLayerParam = initParams.eigenLayerParam;

        address underlyingToken = address(IStrategy(eigenLayerParam.strategy).underlyingToken());
        __initializeMellowEigenLayerVaultStorage(
            eigenLayerParam.delegationManager,
            eigenLayerParam.strategyManager,
            eigenLayerParam.strategy,
            eigenLayerParam.operator,
            eigenLayerParam.claimWithdrawalsMax
        );
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

        address this_ = address(this);
        uint256 timestamp = block.timestamp;

        uint256 nonce = eigenLayerDelegationManager().stakerNonce(this_);

        bytes32 stakerDigestHash = IDelegationManager(eigenLayerParam.delegationManager)
            .calculateStakerDelegationDigestHash(
            this_, nonce, eigenLayerParam.operator, eigenLayerParam.expiry + timestamp
        );

        _setHashAsSigned(stakerDigestHash);
        eigenLayerParam.delegationSignature =
            abi.encode(keccak256(abi.encode(this_, timestamp, stakerDigestHash)));

        ISignatureUtils.SignatureWithExpiry memory stakerSignatureAndExpiry = ISignatureUtils
            .SignatureWithExpiry(
            eigenLayerParam.delegationSignature, eigenLayerParam.expiry + timestamp
        );

        ISignatureUtils.SignatureWithExpiry memory approverSignatureAndExpiry =
            ISignatureUtils.SignatureWithExpiry(abi.encode(0), 0);
        eigenLayerDelegationManager().delegateToBySignature(
            this_,
            eigenLayerParam.operator,
            stakerSignatureAndExpiry,
            approverSignatureAndExpiry,
            eigenLayerParam.salt
        );
        _revokeHash(stakerDigestHash);
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
        uint256 liquid = IERC20(asset()).balanceOf(address(this));
        if (liquid >= assets) {
            return super._withdraw(caller, receiver, owner, assets, shares);
        }

        uint256 stakedShares = previewWithdraw(assets - liquid);
        if (stakedShares > 0) {
            _pushToWithdrawalQueue(receiver, stakedShares);

            if (caller != owner) {
                _spendAllowance(owner, caller, stakedShares);
            }
        }

        _burn(owner, shares);
        if (liquid != 0) {
            IERC20(asset()).safeTransfer(receiver, liquid);
        }

        // emitting event with transfered + new pending assets
        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    function _pushToWithdrawalQueue(address account, uint256 stakedShares) internal {
        IStrategy[] memory strategies = new IStrategy[](1);
        uint256[] memory shares = new uint256[](1);
        strategies[0] = eigenLayerStrategy();
        shares[0] = stakedShares;

        IDelegationManager.QueuedWithdrawalParams[] memory queuedWithdrawalParams =
            new IDelegationManager.QueuedWithdrawalParams[](1);
        queuedWithdrawalParams[0] = IDelegationManager.QueuedWithdrawalParams({
            strategies: strategies,
            shares: shares,
            withdrawer: address(this)
        });

        uint256 nonce = eigenLayerDelegationManager().cumulativeWithdrawalsQueued(address(this));
        bytes32[] memory withdrawalRoots =
            eigenLayerDelegationManager().queueWithdrawals(queuedWithdrawalParams);

        IDelegationManager.Withdrawal memory withdrawalData = IDelegationManager.Withdrawal({
            staker: address(this),
            delegatedTo: eigenLayerStrategyOperator(),
            withdrawer: address(this),
            nonce: nonce,
            startBlock: uint32(block.number),
            strategies: strategies,
            shares: shares
        });

        bytes32 withdrawalRoot =
            eigenLayerDelegationManager().calculateWithdrawalRoot(withdrawalData);
        require(withdrawalRoots[0] == withdrawalRoot, "Vault: withdrawalRoot mismatch");

        mapping(address account => IDelegationManager.Withdrawal[]) storage withdrawals =
            _getEigenLayerWithdrawalQueue();

        require(
            withdrawals[account].length < eigenLayerClaimWithdrawalsMax(),
            "Vault: withdrawal queue size limit is reached"
        );
        withdrawals[account].push(withdrawalData);
    }

    function claim(address account, address recipient)
        external
        virtual
        nonReentrant
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
