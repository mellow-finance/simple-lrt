// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../../src/tokens/AaveToken.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract APoolMock is IAToken, IAPool, ERC4626 {
    using SafeERC20 for IERC20;

    constructor(address asset_) ERC20("AaveMock", "AM") ERC4626(IERC20(asset_)) {}

    function POOL() external view returns (IAPool) {
        return IAPool(address(this));
    }

    function UNDERLYING_ASSET_ADDRESS() external view returns (address) {
        return asset();
    }

    function supply(address asset_, uint256 amount, address onBehalfOf, uint16 /* referralCode */ )
        external
    {
        require(onBehalfOf == msg.sender, "APoolMock: onBehalfOf mismatch");
        require(asset() == asset_, "APoolMock: asset mismatch");
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);
    }

    function withdraw(address asset_, uint256 amount, address to) external returns (uint256) {
        require(asset() == asset_, "APoolMock: asset mismatch");
        _burn(msg.sender, amount);
        IERC20(asset()).safeTransfer(to, amount);
    }

    function getReserveData(address asset_) external view returns (ReserveDataLegacy memory) {}
}
