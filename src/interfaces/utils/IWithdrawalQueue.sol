// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

interface IWithdrawalQueue {
    // balance = pending + claimable

    function balance() external view returns (uint256);
    function pendingAssets() external view returns (uint256);
    function claimableAssets() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);
    function pendingAssetsOf(address account) external view returns (uint256);
    function claimableAssetsOf(address account) external view returns (uint256);

    function request(address account, uint256 amount) external;

    function claim(address account, address recipient, uint256 maxAmount)
        external
        returns (uint256 amount);
}
