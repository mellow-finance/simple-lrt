// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

interface IWithdrawalQueue {
    function registerWithdrawal(address account, uint256 amount) external;

    function pending(address account)
        external
        view
        returns (uint256 pendingShares_, uint256 pendingAssets_);
    function claimable(address account) external view returns (uint256 claimableAssets_);
    function claim(address account, address recipient) external returns (uint256 amount);
}
