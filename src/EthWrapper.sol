// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.26;

import "./interfaces/IWETH.sol";
import "./interfaces/ISTETH.sol";
import "./interfaces/IWSTETH.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./Vault.sol";

contract EthWrapper {
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    using SafeERC20 for IERC20;

    function _wrap(address depositToken, uint256 amount) internal {
        if (amount == 0) {
            revert("EthVault: amount must be greater than 0");
        }

        if (depositToken != ETH && depositToken != WETH && depositToken != stETH && depositToken != wstETH) {
            revert("EthVault: invalid depositToken");
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
            payable(wstETH).transfer(amount);
            depositToken = wstETH;
        }

        if (depositToken == stETH) {
            IERC20(stETH).safeIncreaseAllowance(wstETH, amount);
            IWSTETH(wstETH).wrap(amount);
            depositToken = wstETH;
        }
    }

    receive() external payable {}
}
