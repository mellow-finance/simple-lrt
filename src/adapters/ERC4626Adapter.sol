// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/adapters/IERC4626Adapter.sol";

contract ERC4626Adapter is IERC4626Adapter {
    address public immutable vault;
    address public immutable asset;

    constructor(address vault_) {
        vault = vault_;
        asset = IERC4626(vault).asset();
    }

    /// @inheritdoc IProtocolAdapter
    function maxDeposit(address token) external view returns (uint256) {
        return IERC4626(token).maxDeposit(vault);
    }

    /// @inheritdoc IProtocolAdapter
    function assetOf(address token) external view returns (address) {
        return IERC4626(token).asset();
    }

    /// @inheritdoc IProtocolAdapter
    function maxWithdraw(address token) external view returns (uint256) {
        return IERC4626(token).maxWithdraw(vault);
    }

    /// @inheritdoc IProtocolAdapter
    function handleVault(address /* token */ ) external pure returns (address withdrawalQueue) {
        return address(0);
    }

    /// @inheritdoc IProtocolAdapter
    function validateFarmData(bytes calldata /* data*/ ) external pure {
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
        IERC4626(token).deposit(assets, vault);
    }
}
