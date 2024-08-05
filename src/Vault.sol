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

    // @notice The maximum amount of LRT that can be minted
    uint256 limit;

    /**
     * @notice The constructor
     *
     * @param name The name of the LRT token
     * @param ticker The ticker of the LRT token
     * @param admin The address of the admin
     *
     * @dev Admin should be a timelock contract
     *
     * @custom:effects
     * - Sets the `name` and `ticker` state variables for ERC20
     * - Grants the DEFAULT_ADMIN_ROLE to the `admin` param
     */
    constructor(
        string memory name,
        string memory ticker,
        address admin
    ) ERC20(name, ticker) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /**
     * @notice Set the limit of LRT that can be minted
     *
     * @param _limit The new limit
     *
     *
     * @custom:requirements
     * - MUST have admin role to set limit
     *
     * @custom:effects
     * - Updates `limit` state variable
     * - Emits NewLimit event
     */
    function setLimit(uint256 _limit) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Vault: must have admin role to set limit"
        );
        limit = _limit;
        emit NewLimit(_limit);
    }

    /**
     * @notice Deposit either of wstETH / stETH / wETH / ETH into the vault.
     *
     * @param token The address of the token to deposit.
     *              0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE is used for raw ETH and
     *              ether is sent directly as a value in this case
     * @param amount The amount of the token to deposit. In case of raw ETH it should
     *               be equal to `msg.value`
     * @param recipient The address of the recipient of the LRT
     * @param referral The address of the referral
     *
     * @custom:requirements
     * - The amount of the token to deposit MUST be greater than 0
     * - The token sent MUST be either of wstETH / stETH / wETH / ETH
     * - If raw ETH is sent then `token` MUST be 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
     * - If raw ETH is sent `amount` MUST be equal to `msg.value`
     * - If anything other than raw ETH is sent `msg.value` MUST be 0
     * - If anything other than raw ETH is sent the sender MUST ERC20-approve at least `amount`
     *   to this contract
     *
     * @custom:effects
     * - Transfers the `token` with `amount` from the sender to the vault
     * - Mints the `amount` of LRT to the `recipient`
     * - Calls `push()` to transfer the wstETH to the Symbiotic default bond
     * - Emits Deposit event
     */
    function deposit(
        address token,
        uint256 amount,
        address recipient,
        address referral
    ) external payable {
        amount = _trimToLimit(address(this), amount);
        amount = _transferToVaultAndConvertToWsteth(token, amount, referral);
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

    /**
     *@notice Pushes all wstETH from the vault balance to the Symbiotic default bond (up to its limit)
     *
     *@dev This function is called after a deposit to the vault and can be called by
     *     any external address to ensure that the wstETH is earning yield.
     *
     *@custom:effects
     * - calls IDefaultBond#deposit with the vault's balance of wstETH (up to the limit of the bond)
     * - Emits Push event
     */
    function push() public {
        uint256 amount = IERC20(wstETH).balanceOf(address(this));
        amount = _trimToLimit(DEFAULT_BOND, amount);
        if (amount == 0) {
            return;
        }
        IERC20(wstETH).safeIncreaseAllowance(DEFAULT_BOND, amount);
        IDefaultBond(DEFAULT_BOND).deposit(address(this), amount);
        emit Push(amount);
    }

    /**
     * @dev Internal function to transfer the token to the vault and convert it to wstETH
     */
    function _transferToVaultAndConvertToWsteth(
        address token,
        uint256 amount,
        address referral
    ) internal returns (uint256) {
        if (amount == 0) {
            revert("Vault: amount must be greater than 0");
        }
        if (token != ETH) {
            require(msg.value == 0, "Vault: cannot send ETH with token");
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }
        if (token == WETH) {
            IWETH(WETH).withdraw(amount);
            token = ETH;
        }
        if (token == ETH) {
            require(msg.value == amount, "Vault: incorrect amount of ETH");
            ISTETH(stETH).submit{value: amount}(referral);
            token = stETH;
        }
        if (token == stETH) {
            IERC20(stETH).safeIncreaseAllowance(wstETH, amount);
            amount = IWSTETH(wstETH).wrap(amount);
            token = wstETH;
        }
        if (token != wstETH) {
            revert("Vault: invalid token");
        }
        return amount;
    }

    /**
     * @dev Internal function to trim amounts for both Vault and Symbiotic Default Bond limits
     */
    function _trimToLimit(
        address vault,
        uint256 amount
    ) internal view returns (uint256) {
        uint256 leftover = ILimit(vault).limit() - ILimit(vault).totalSupply();
        return amount > leftover ? leftover : amount;
    }

    event Deposit(address indexed user, uint256 amount, address referral);
    event Withdrawal(address indexed user, uint256 amount);
    event NewLimit(uint256 limit);
    event Push(uint256 amount);
}
