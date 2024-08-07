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
import "./interfaces/ISymbioticVault.sol";

contract Vault is ERC20, AccessControlEnumerable {
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    using SafeERC20 for IERC20;

    // @notice The maximum amount of LRT that can be minted
    uint256 public limit;
    // @notice The address of the underlying SymbioticBond
    address public immutable symbioticBond;
    // @notice The address of the underlying SymbioticVault
    address public immutable symbioticVault;
    // @notice The address of the farms for rewards
    mapping(address => address) public farms;
    // @notice Helper info about user's claim from Symbiotic vault
    mapping(address => uint256[]) public claimEpochs;

    /**
     * @notice The constructor
     *
     * @param _name The name of the LRT token
     * @param _ticker The ticker of the LRT token
     * @param _symbioticBond The address of the underlying SymbioticBond
     * @param _symbioticVault The address of the underlying SymbioticVault
     * @param _limit The maximum amount of LRT that can be minted
     * @param _admin The address of the admin
     *
     * @dev Admin should be a timelock contract
     *
     * @custom:effects
     * - Sets the `name` and `ticker` state variables for ERC20
     * - Grants the DEFAULT_ADMIN_ROLE to the `admin` param
     */
    constructor(
        string memory _name,
        string memory _ticker,
        address _symbioticBond,
        address _symbioticVault,
        uint256 _limit,
        address _admin
    ) ERC20(_name, _ticker) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        symbioticVault = _symbioticVault;
        symbioticBond = _symbioticBond;
        limit = _limit;
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
        _requireAdmin();
        limit = _limit;
        emit NewLimit(_limit);
    }

    /**
     * @notice Set the farm for the reward token
     *
     * @param rewardToken The address of the reward token
     * @param farm The address of the farm
     *
     * @custom:requirements
     * - MUST have admin role to set farm
     * - The reward token MUST NOT be stETH, wstETH or WETH
     *
     * @custom:effects
     * - Updates the `farms` mapping
     *
     */
    function setFarm(address rewardToken, address farm) external {
        _requireAdmin();
        if (
            (rewardToken == WETH) ||
            (rewardToken == stETH) ||
            (rewardToken == wstETH)
        ) {
            revert("Vault: cannot set farm for stETH, wstETH or WETH");
        }
        farms[rewardToken] = farm;
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
     * - Calls `_pushToSymbioticBond()` to transfer the wstETH to the Symbiotic default bond
     * - Calls `_pushToSymbioticVault()` to transfer bond tokens to the Symbiotic Vault
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

    /**
     * @notice Withdraw or schedule withdraw from the vault.
     * @dev If some amount available in the vault for immmediate withdrawal in the form
     * of wstETH, it will be withdrawn immediately. Otherwise, the amount will be scheduled
     * for withdrawal from the symbiotic vault.
     *
     * @param amount The amount of the LRT to withdraw
     *
     * @custom:effects
     * - Burns the `amount` of LRT from the sender
     * - Transfers maximum possible wstETH (to fulfill the request) from the vault to the sender
     * - Redeems maximum possible bondToken and transfers wstETH proceeds
     *   (to fulfill the request) from the vault to the sender
     * - Shedules withdrawal of the remaining amount from the symbiotic vault
     * - Adds the epoch for withdrawal to the `claimEpochs` mapping
     * - Emits Withdrawal event
     */
    function withdraw(uint256 amount) external {
        uint256 balance = IERC20(address(this)).balanceOf(msg.sender);
        amount = amount > balance ? amount : balance;
        if (amount == 0) {
            return;
        }
        _burn(msg.sender, amount);
        emit Withdrawal(msg.sender, amount);

        uint256 wsethBalance = IERC20(wstETH).balanceOf(address(this));
        uint256 bondBalance = IERC20(symbioticBond).balanceOf(address(this));
        uint256 sharesBalance = IERC20(symbioticVault).balanceOf(address(this));
        uint256 amountToClaim = ((wsethBalance + bondBalance + sharesBalance) *
            amount) / totalSupply();

        uint256 wstEthClaimAmount = amountToClaim > wsethBalance
            ? wsethBalance // @notice The address of the underlying SymbioticBond
            : amountToClaim;
        IERC20(wstETH).safeTransfer(msg.sender, wstEthClaimAmount);
        amountToClaim -= wstEthClaimAmount;

        uint256 bondClaimAmount = amountToClaim > bondBalance
            ? bondBalance
            : amountToClaim;
        IDefaultBond(symbioticBond).withdraw(msg.sender, bondClaimAmount);
        amountToClaim -= bondClaimAmount;

        if (amountToClaim == 0) {
            return;
        }

        // @notice The address of the underlying SymbioticBond
        ISymbioticVault(symbioticVault).withdraw(msg.sender, amountToClaim);
        claimEpochs[msg.sender].push(
            ISymbioticVault(symbioticVault).currentEpoch()
        );
    }

    /**
     * @notice Claim the available for withdraw wstETH (from the symbiotic vault)
     *
     * @custom:effects
     * - Calls `ISymbioticVault#claim` for each epoch in the `claimEpochs` mapping
     * - Clears `claimEpochs` mapping for this user
     */
    function claim() external {
        for (uint256 i = 0; i < claimEpochs[msg.sender].length; i++) {
            try
                ISymbioticVault(symbioticVault).claim(
                    msg.sender,
                    claimEpochs[msg.sender][i]
                )
            {
                delete claimEpochs[msg.sender][i];
            } catch {
                continue;
            }
        }
        delete claimEpochs[msg.sender];
    }

    /**
     * @notice Pushes all wstETH from the vault balance to the Symbiotic default bond (up to its limit)
     *         and all bond tokens to the Symbiotic Vault
     * @dev This function is called after a deposit to the vault and can be called by
     *      any external address to ensure that the wstETH is earning yield.
     *
     * @custom:effects
     * - Calls `_pushToSymbioticBond` to transfer the wstETH to the Symbiotic default bond
     * - Calls `_pushToSymbioticVault` to transfer the bondTokens to the Symbiotic Vault
     */
    function push() public {
        _pushToSymbioticBond();
        _pushToSymbioticVault();
    }

    /**
     * @notice Pushes all rewards from the vault to the farm
     *
     * @param token The address of the token to push
     *
     * @custom:requirements
     * - The farm for the `token` MUST be set
     *
     * @custom:effects
     * - Send all the balance of `token` from the vault to the farm
     */
    function pushRewards(address token) external {
        address farm = farms[token];
        require(farm != address(0), "Vault: farm not set");
        IERC20(token).safeTransfer(
            farm,
            IERC20(token).balanceOf(address(this))
        );
    }

    function _pushToSymbioticVault() internal {
        uint256 bondAmount = IERC20(symbioticBond).balanceOf(address(this));
        IERC20(symbioticBond).safeIncreaseAllowance(symbioticVault, bondAmount);
        (uint256 amount, uint256 shares) = ISymbioticVault(symbioticVault)
            .deposit(address(this), bondAmount);
        emit PushToSymbioticVault(bondAmount, amount, shares);
    }

    // @notice The address of the underlying SymbioticBond
    /**
    // @notice The address of the underlying SymbioticBond
     *@notice Pushes all wstETH from the vault balance to the Symbiotic default bond (up to its limit)
     *
     *@dev This function is called after a deposit to the vault and can be called by
     *     any external address to ensure that the wstETH is earning yield.
     *
     *@custom:effects
     * - calls IDefaultBond#deposit with the vault's balance of wstETH (up to the limit of the bond)
     * - Emits _PushSymbioticBond event
     */
    function _pushToSymbioticBond() internal {
        uint256 amount = IERC20(wstETH).balanceOf(address(this));
        amount = _trimToLimit(symbioticBond, amount);
        if (amount == 0) {
            return;
        }
        IERC20(wstETH).safeIncreaseAllowance(symbioticBond, amount);
        IDefaultBond(symbioticBond).deposit(address(this), amount);
        emit PushToSymbioticBond(amount);
        // @notice The address of the underlying SymbioticBond
    }

    /**
     * @dev Internal function to transfer the token to the
     // @notice The address of the underlying SymbioticBond vault and convert it to wstETH
     */
    // @notice The address of the underlying SymbioticBond
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

    function _requireAdmin() internal view {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Vault: must have admin role to set limit"
        );
    }

    event Deposit(address indexed user, uint256 amount, address referral);
    event Withdrawal(address indexed user, uint256 amount);
    event NewLimit(uint256 limit);
    event PushToSymbioticBond(uint256 amount);
    event PushToSymbioticVault(
        uint256 initialAmount,
        uint256 amount,
        uint256 shares
    );
}
