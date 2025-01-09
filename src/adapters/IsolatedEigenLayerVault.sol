// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/adapters/IIsolatedEigenLayerVault.sol";

contract IsolatedEigenLayerVault is IIsolatedEigenLayerVault, Initializable {
    using SafeERC20 for IERC20;

    address public factory;
    address public vault;
    address public asset;

    modifier onlyVault() {
        require(msg.sender == vault, "Only vault");
        _;
    }

    function initialize(address vault_) external virtual initializer {
        __init_IsolatedEigenLayerVault(vault_);
    }

    function __init_IsolatedEigenLayerVault(address vault_) internal onlyInitializing {
        factory = msg.sender;
        vault = vault_;
        asset = IERC4626(vault_).asset();
    }

    /// @inheritdoc IIsolatedEigenLayerVault
    function delegateTo(
        address manager,
        address operator,
        ISignatureUtils.SignatureWithExpiry memory signature,
        bytes32 salt
    ) external {
        IDelegationManager(manager).delegateTo(operator, signature, salt);
    }

    /// @inheritdoc IIsolatedEigenLayerVault
    function deposit(address manager, address strategy, uint256 assets)
        external
        virtual
        onlyVault
    {
        IERC20 asset_ = IERC20(asset);
        asset_.safeTransferFrom(vault, address(this), assets);
        asset_.safeIncreaseAllowance(manager, assets);
        IStrategyManager(manager).depositIntoStrategy(IStrategy(strategy), asset_, assets);
    }

    /// @inheritdoc IIsolatedEigenLayerVault
    function withdraw(address queue, address reciever, uint256 request, bool flag)
        external
        virtual
        onlyVault
    {
        IEigenLayerWithdrawalQueue(queue).request(reciever, request, flag);
    }

    /// @inheritdoc IIsolatedEigenLayerVault
    function processClaim(
        IRewardsCoordinator coodrinator,
        IRewardsCoordinator.RewardsMerkleClaim memory farmData,
        IERC20 rewardToken
    ) external onlyVault {
        address this_ = address(this);
        uint256 rewards = rewardToken.balanceOf(this_);
        coodrinator.processClaim(farmData, this_);
        rewards = rewardToken.balanceOf(this_) - rewards;
        if (rewards != 0) {
            rewardToken.safeTransfer(vault, rewards);
        }
    }

    /// @inheritdoc IIsolatedEigenLayerVault
    function claimWithdrawal(
        IDelegationManager manager,
        IDelegationManager.Withdrawal calldata data
    ) external virtual returns (uint256 assets) {
        address this_ = address(this);
        (,,, address queue) = IIsolatedEigenLayerVaultFactory(factory).instances(this_);
        require(msg.sender == queue, "IsolatedEigenLayerVault: forbidden");
        IERC20 asset_ = IERC20(asset);
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = asset_;
        manager.completeQueuedWithdrawal(data, tokens, 0, true);
        assets = asset_.balanceOf(this_);
        asset_.safeTransfer(queue, assets);
    }

    /// @inheritdoc IIsolatedEigenLayerVault
    function queueWithdrawals(
        IDelegationManager manager,
        IDelegationManager.QueuedWithdrawalParams[] calldata requests
    ) external {
        (,,, address queue) = IIsolatedEigenLayerVaultFactory(factory).instances(address(this));
        require(msg.sender == queue, "IsolatedEigenLayerVault: forbidden");
        manager.queueWithdrawals(requests);
    }
}
