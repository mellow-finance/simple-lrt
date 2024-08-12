// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "./interfaces/IWETH.sol";
import "./interfaces/ISTETH.sol";
import "./interfaces/IWSTETH.sol";

import "./BaseVault.sol";

contract EthVault is BaseVault {
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    using SafeERC20 for IERC20;

    constructor(string memory _name, string memory _ticker) BaseVault(_name, _ticker) {}

    function _setFarmChecks(address rewardToken, FarmData memory farmData) internal virtual override {
        super._setFarmChecks(rewardToken, farmData);
        if (rewardToken == WETH || rewardToken == stETH) {
            revert("EthVault: forbidden reward token");
        }
    }

    function _deposit(address depositToken, uint256 amount, address referral) internal virtual override {
        if (amount == 0) {
            revert("EthVault: amount must be greater than 0");
        }

        if (depositToken != ETH) {
            require(msg.value == 0, "EthVault: cannot send ETH with depositToken");
            IERC20(depositToken).safeTransferFrom(msg.sender, address(this), amount);
        } else {
            require(msg.value == amount, "EthVault: incorrect amount of ETH");
        }

        if (depositToken == WETH) {
            IWETH(WETH).withdraw(amount);
            depositToken = ETH;
        }

        if (depositToken == ETH) {
            ISTETH(stETH).submit{value: amount}(referral);
            depositToken = stETH;
        }

        if (depositToken == stETH) {
            IERC20(stETH).safeIncreaseAllowance(wstETH, amount);
            IWSTETH(wstETH).wrap(amount);
            depositToken = wstETH;
        }

        if (depositToken != wstETH) revert("EthVault: invalid depositToken");
    }

    receive() external payable {}
}
