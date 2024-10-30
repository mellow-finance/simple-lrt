// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {ERC4626Vault} from "./ERC4626Vault.sol";
import {MellowEigenLayerVaultStorage} from "./MellowEigenLayerVaultStorage.sol";
import {VaultControlStorage} from "./VaultControl.sol";
import "./interfaces/vaults/IMellowEigenLayerVault.sol";

import "./EigenLayerWithdrawalQueue.sol";

contract MellowEigenLayerVault is
    IMellowEigenLayerVault,
    MellowEigenLayerVaultStorage,
    ERC4626Vault
{
    using SafeERC20 for IERC20;
    using Math for uint256;

    // in EigenLayer contracts equals to 1e3, but can be changed with a new version
    uint256 public immutable SHARES_OFFSET;
    // in EigenLayer contracts equals to 1e3, but can be changed with a new version
    uint256 public immutable BALANCE_OFFSET;

    constructor(
        bytes32 contractName_,
        uint256 contractVersion_,
        uint256 sharesOffset,
        uint256 balanceOffset
    )
        MellowEigenLayerVaultStorage(contractName_, contractVersion_)
        VaultControlStorage(contractName_, contractVersion_)
    {
        SHARES_OFFSET = sharesOffset;
        BALANCE_OFFSET = balanceOffset;
    }

    function initialize(InitParams memory initParams) public virtual initializer {
        __initialize(initParams);
    }

    function __initialize(InitParams memory initParams) internal virtual onlyInitializing {
        EigenLayerParams memory params = initParams.eigenLayerParams;
        address underlyingToken = address(IStrategy(params.strategy).underlyingToken());
        __initializeMellowEigenLayerVaultStorage(
            params.delegationManager,
            params.strategyManager,
            params.strategy,
            params.operator,
            params.claimWithdrawalsMax,
            initParams.withdrawalQueue
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

        IDelegationManager(params.delegationManager).delegateTo(
            params.operator, params.approverSignature, params.salt
        );
    }

    /*  
        TODO:
            1. add rewards logic
            2. add maxMint, maxDeposit, maxRedeem, maxWithdraw function overrides
            3. finalize EigenLayerWithdrawalQueue
            4. finalize Claimer contract by adding ELWQ logic for transferred pending assets 
    */

    /// ------------------ ERC4626 overrides ------------------

    /// @inheritdoc IERC4626
    function totalAssets()
        public
        view
        virtual
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256)
    {
        return strategy().userUnderlyingView(address(this));
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        IStrategy strategy_ = strategy();
        uint256 virtualTokenBalance = IERC20(asset()).balanceOf(address(strategy_)) + BALANCE_OFFSET;
        uint256 virtualShareAmount = strategy_.totalShares() + SHARES_OFFSET;
        return assets.mulDiv(virtualShareAmount, virtualTokenBalance, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        IStrategy strategy_ = strategy();
        uint256 virtualTokenBalance = IERC20(asset()).balanceOf(address(strategy_)) + BALANCE_OFFSET;
        uint256 virtualShareAmount = strategy_.totalShares() + SHARES_OFFSET;
        return shares.mulDiv(virtualTokenBalance, virtualShareAmount, rounding);
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        virtual
        override
    {
        super._deposit(caller, receiver, assets, shares);
        address asset_ = asset();
        IStrategyManager strategyManager_ = strategyManager();
        IERC20(asset_).safeIncreaseAllowance(address(strategyManager_), assets);
        strategyManager_.depositIntoStrategy(strategy(), IERC20(asset_), assets);
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }
        _burn(owner, shares);
        EigenLayerWithdrawalQueue(withdrawalQueue()).request(receiver, assets, receiver == owner);
        // emitting event with new pending assets
        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    // ------ proxy calls from EigenLayerWithdrawalQueue ---------

    function proxyRequestWithdrawals(IDelegationManager.QueuedWithdrawalParams calldata request)
        external
        returns (bytes32[] memory)
    {
        require(_msgSender() == withdrawalQueue(), "Vault: forbidden");
        IDelegationManager.QueuedWithdrawalParams[] memory requests =
            new IDelegationManager.QueuedWithdrawalParams[](1);
        requests[0] = request;
        return delegationManager().queueWithdrawals(requests);
    }

    function proxyClaimWithdrawals(IDelegationManager.Withdrawal calldata data)
        external
        returns (uint256 assets)
    {
        address withdrawalQueue_ = withdrawalQueue();
        require(_msgSender() == withdrawalQueue_, "Vault: forbidden");
        IERC20 asset_ = IERC20(asset());
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = asset_;
        delegationManager().completeQueuedWithdrawal(data, tokens, 0, true);
        assets = asset_.balanceOf(address(this));
        asset_.safeTransfer(withdrawalQueue_, assets);
    }

    // ----- proxy calls in EigenLayerWithdrawalQueue -------

    function claim(address account, address recipient, uint256 maxAmount)
        external
        virtual
        nonReentrant
        returns (uint256 claimedAmount)
    {
        require(account == _msgSender(), "Vault: forbidden");
        return EigenLayerWithdrawalQueue(withdrawalQueue()).claim(account, recipient, maxAmount);
    }

    function pendingAssetsOf(address account) public view returns (uint256 assets) {
        return EigenLayerWithdrawalQueue(withdrawalQueue()).pendingAssetsOf(account);
    }

    function claimableAssetsOf(address account) public view returns (uint256 assets) {
        return EigenLayerWithdrawalQueue(withdrawalQueue()).claimableAssetsOf(account);
    }
}
