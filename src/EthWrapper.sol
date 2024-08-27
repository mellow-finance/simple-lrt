// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./interfaces/utils/IEthWrapper.sol";

contract EthWrapper is IEthWrapper {
    using SafeERC20 for IERC20;

    /// @inheritdoc IEthWrapper
    address public immutable WETH;
    /// @inheritdoc IEthWrapper
    address public immutable wstETH;
    /// @inheritdoc IEthWrapper
    address public immutable stETH;
    /// @inheritdoc IEthWrapper
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    constructor(address WETH_, address wstETH_, address stETH_) {
        WETH = WETH_;
        wstETH = wstETH_;
        stETH = stETH_;
    }

    function _wrap(address depositToken, uint256 amount) internal returns (uint256) {
        require(amount > 0, "EthWrapper: amount must be greater than 0");
        require(
            depositToken == ETH || depositToken == WETH || depositToken == stETH
                || depositToken == wstETH,
            "EthWrapper: invalid depositToken"
        );

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
            (bool success,) = payable(wstETH).call{value: amount}("");
            require(success, "EthWrapper: ETH transfer failed");
            depositToken = wstETH;
            amount = IERC20(wstETH).balanceOf(address(this));
        }

        if (depositToken == stETH) {
            IERC20(stETH).safeIncreaseAllowance(wstETH, amount);
            amount = IWSTETH(wstETH).wrap(amount);
            depositToken = wstETH;
        }

        return amount;
    }

    receive() external payable {}

    /// @inheritdoc IEthWrapper
    function deposit(
        address depositToken,
        uint256 amount,
        address vault,
        address receiver,
        address referral
    ) external payable returns (uint256 shares) {
        amount = _wrap(depositToken, amount);
        IERC20(wstETH).safeIncreaseAllowance(vault, amount);
        return IERC4626Vault(vault).deposit(amount, receiver, referral);
    }
}
