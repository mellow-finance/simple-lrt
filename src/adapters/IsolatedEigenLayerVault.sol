// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/adapters/IIsolatedEigenLayerVault.sol";

contract IsolatedEigenLayerVault is IIsolatedEigenLayerVault {
    using SafeERC20 for IERC20;

    address public immutable factory;
    address public immutable vault;
    address public immutable asset;

    modifier onlyVault() {
        require(msg.sender == vault, "Only vault");
        _;
    }

    constructor(address vault_) {
        factory = msg.sender;
        vault = vault_;
        asset = IERC4626(vault_).asset();
    }

    function delegateTo(
        address manager,
        address operator,
        ISignatureUtils.SignatureWithExpiry memory signature,
        bytes32 salt
    ) external {
        IDelegationManager(manager).delegateTo(operator, signature, salt);
    }

    function deposit(address manager, address strategy, uint256 assets) external onlyVault {
        IStrategyManager(manager).depositIntoStrategy(IStrategy(strategy), IERC20(asset), assets);
    }

    function withdraw(address queue, address reciever, uint256 request, bool flag)
        external
        onlyVault
    {
        IEigenLayerWithdrawalQueue(queue).request(reciever, request, flag);
    }

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

    function claimWithdrawal(
        IDelegationManager manager,
        IDelegationManager.Withdrawal calldata data
    ) external returns (uint256 assets) {
        address this_ = address(this);
        (,,, address queue) = IIsolatedEigenLayerVaultFactory(factory).instances(this_);
        require(msg.sender == queue, "Only queue");
        IERC20 asset_ = IERC20(asset);
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = asset_;
        manager.completeQueuedWithdrawal(data, tokens, 0, true);
        assets = asset_.balanceOf(this_);
        asset_.safeTransfer(queue, assets);
    }

    function queueWithdrawals(
        IDelegationManager manager,
        IDelegationManager.QueuedWithdrawalParams[] calldata requests
    ) external {
        (,,, address queue) = IIsolatedEigenLayerVaultFactory(factory).instances(address(this));
        require(msg.sender == queue, "Only queue");
        manager.queueWithdrawals(requests);
    }
}
