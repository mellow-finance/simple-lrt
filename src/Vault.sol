// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/ISTETH.sol";
import "./interfaces/IWSTETH.sol";
import "./interfaces/IDefaultBond.sol";
import "./interfaces/ILimit.sol";

contract Vault is ERC20, AccessControlEnumerable {
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant DEFAULT_BOND =
        0xC329400492c6ff2438472D4651Ad17389fCb843a;

    using SafeERC20 for IERC20;

    // Limit in wstETH
    uint256 limit;

    constructor(
        string memory name,
        string memory ticker,
        address admin
    ) ERC20(name, ticker) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // Set under openzeppelin timelock
    function setLimit(uint256 _limit) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Vault: must have admin role to set limit"
        );
        limit = _limit;
    }

    function deposit(
        address token,
        uint256 amount,
        address recipient,
        address referral
    ) external payable {
        amount = _trimToLimit(address(this), amount);
        _transferToVaultAndConvertToWsteth(token, amount, referral);
        push();
        _mint(recipient, amount);
        emit Deposit(recipient, amount, referral);
    }

    function withdraw(uint256 amount) external {
        // revert on overflow
        uint256 balance = IERC20(address(this)).balanceOf(msg.sender);
        amount = amount > balance ? amount : balance;
        IDefaultBond(DEFAULT_BOND).withdraw(msg.sender, amount);
        IERC20(wstETH).safeTransfer(msg.sender, amount);
        _burn(msg.sender, amount);
        emit Withdrawal(msg.sender, amount);
    }

    // Push everything to the bond
    function push() public {
        uint256 amount = IERC20(wstETH).balanceOf(address(this));
        amount = _trimToLimit(DEFAULT_BOND, amount);
        if (amount == 0) {
            return;
        }
        IERC20(wstETH).safeIncreaseAllowance(DEFAULT_BOND, amount);
        IDefaultBond(DEFAULT_BOND).deposit(address(this), amount);
    }

    function _transferToVaultAndConvertToWsteth(
        address token,
        uint256 amount,
        address referral
    ) internal {
        if (amount == 0) {
            revert("Vault: amount must be greater than 0");
        }
        if (token != ETH) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }
        if (token == WETH) {
            IWETH(WETH).withdraw(amount);
            token = ETH;
        }
        if (token == ETH) {
            ISTETH(stETH).submit{value: amount}(referral);
            token = stETH;
        }
        if (token == stETH) {
            IERC20(stETH).safeIncreaseAllowance(wstETH, amount);
            IWSTETH(wstETH).submit(amount);
            token = wstETH;
        }
        if (token != wstETH) {
            revert("Vault: invalid token");
        }
    }

    function _trimToLimit(
        address vault,
        uint256 amount
    ) internal view returns (uint256) {
        uint256 leftover = ILimit(vault).limit() - ILimit(vault).totalSupply();
        return amount > leftover ? leftover : amount;
    }

    event Deposit(address indexed user, uint256 amount, address referral);
    event Withdrawal(address indexed user, uint256 amount);
}
