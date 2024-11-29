// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IProtocolAdapter {
    function vault() external view returns (address);

    function maxDeposit(address symbioticVault) external view returns (uint256);

    function assetOf(address symbioticVault) external view returns (address);

    function maxWithdraw(address strategy) external view returns (uint256);

    function validateFarmData(bytes calldata data) external view;

    function pushRewards(address rewardToken, bytes calldata farmData, bytes memory rewardData)
        external;

    function withdraw(
        address vault,
        address withdrawalQueue,
        address receiver,
        uint256 request,
        address owner
    ) external;

    function deposit(address vault, uint256 assets) external;

    function handleVault(address vault) external returns (address withdrawalQueue);
}
