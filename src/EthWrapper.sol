// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/utils/IEthWrapper.sol";

contract EthWrapper is IEthWrapper {
    using SafeERC20 for IERC20;

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function _wrap(address depositToken, uint256 amount) internal returns (uint256) {
        if (amount == 0) {
            revert("EthWrapper: amount must be greater than 0");
        }

        if (
            depositToken != ETH && depositToken != WETH && depositToken != stETH
                && depositToken != wstETH
        ) {
            revert("EthWrapper: invalid depositToken");
        }

        if (depositToken != ETH) {
            require(msg.value == 0, "EthWrapper: cannot send ETH with depositToken");
            IERC20(depositToken).safeTransferFrom(msg.sender, address(this), amount);
        } else {
            require(msg.value == amount, "EthWrapper: incorrect amount of ETH");
        }

        if (depositToken == WETH) {
            IWETH(WETH).withdraw(amount);
            depositToken = ETH;
        }

        if (depositToken == ETH) {
            payable(wstETH).transfer(amount);
            depositToken = wstETH;
        }

        if (depositToken == stETH) {
            IERC20(stETH).safeIncreaseAllowance(wstETH, amount);
            IWSTETH(wstETH).wrap(amount);
            depositToken = wstETH;
        }

        return amount;
    }

    receive() external payable {}

    function deposit(address depositToken, uint256 amount, address vault, address receiver)
        external
        payable
        returns (uint256 shares)
    {
        amount = _wrap(depositToken, amount);
        IERC20(wstETH).safeIncreaseAllowance(vault, amount);
        return IERC4626(vault).deposit(amount, receiver);
    }
}
