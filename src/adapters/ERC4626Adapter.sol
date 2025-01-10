// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/adapters/IERC4626Adapter.sol";

/**
 * @title ERC4626Adapter
 * @notice Implements a tokenized vault adhering to the ERC-4626 standard with notable deviations.
 * @dev This contract violates certain ERC-4626 requirements due to the following limitations:
 * - Withdrawals are not instant. Instead, withdrawn amounts are only partially received immediately,
 *   with the remainder distributed as shares. Consequently, the associated `Withdraw` event may
 *   provide inaccurate information.
 * - The function `totalAssets` and other functions relying on it (e.g., `convertToShares`,
 *   `convertToAssets`, `maxDeposit`, `maxWithdraw`, `maxMint`, `maxRedeem`) must not revert
 *   according to the ERC-4626 specification. However:
 *   - For ERC-4626 adapters, the function `totalAssets` calls `ERC4626Adapter.stakedAt`, which in
 *     turn calls `ERC4626.previewRedeem`. The `previewRedeem` function may revert when a call to
 *     `redeem` would revert, violating the standard.
 *   - The function `RatiosStrategy.calculateState` reverts when funds are withdrawn from the protocol,
 *     and one of the ERC-4626 sub-vaults is paused, as detected by `areWithdrawalsPaused`.
 *     The functions `maxWithdraw` and `maxRedeem` do not account for these withdrawal restrictions and
 *     fail to return 0 as required by ERC-4626.
 */
contract ERC4626Adapter is IERC4626Adapter {
    using SafeERC20 for IERC20;

    address public immutable vault;

    constructor(address vault_) {
        vault = vault_;
    }

    /// @inheritdoc IProtocolAdapter
    function maxDeposit(address token) external view returns (uint256) {
        return IERC4626(token).maxDeposit(vault);
    }

    /// @inheritdoc IProtocolAdapter
    function stakedAt(address token) external view returns (uint256) {
        IERC4626 token_ = IERC4626(token);
        return token_.previewRedeem(token_.balanceOf(vault));
    }

    /// @inheritdoc IProtocolAdapter
    function assetOf(address token) external view returns (address) {
        return IERC4626(token).asset();
    }

    /// @inheritdoc IProtocolAdapter
    function handleVault(address /* token */ ) external pure returns (address withdrawalQueue) {}

    /// @inheritdoc IProtocolAdapter
    function validateRewardData(bytes calldata /* data*/ ) external pure {
        revert("ERC4626Adapter: not implemented");
    }

    /// @inheritdoc IProtocolAdapter
    function pushRewards(
        address, /* rewardToken*/
        bytes calldata, /*farmData*/
        bytes memory /* rewardData */
    ) external pure {
        revert("ERC4626Adapter: not implemented");
    }

    /// @inheritdoc IProtocolAdapter
    function withdraw(
        address token,
        address, /*withdrawalQueue*/
        address reciever,
        uint256 request,
        address /*owner*/
    ) external {
        require(address(this) == vault, "ERC4626Adapter: delegate call only");
        IERC4626(token).withdraw(request, reciever, vault);
    }

    /// @inheritdoc IProtocolAdapter
    function deposit(address token, uint256 assets) external {
        require(address(this) == vault, "ERC4626Adapter: delegate call only");
        IERC20(IERC4626(vault).asset()).safeIncreaseAllowance(token, assets);
        IERC4626(token).deposit(assets, vault);
    }

    /// @inheritdoc IProtocolAdapter
    function areWithdrawalsPaused(address token, address account) external view returns (bool) {
        IERC4626 token_ = IERC4626(token);
        uint256 balance = token_.balanceOf(account);
        return balance != 0 && token_.maxRedeem(account) == 0;
    }
}
