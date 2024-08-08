// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./interfaces/IDefaultBond.sol";
import "./interfaces/ILimit.sol";
import "./interfaces/ISymbioticVault.sol";

// TODO: Upgradeable ERC20 tokens
// TODO: Storage initializer
// TODO: Make an abstract wrap() method in BaseVault and then inherit ETH vault with wrap() implementation
// TODO: View claimable amount
// TODO: Off by 1 errors
// TODO: Pause / unpause
// TODO; Tests
contract BaseVault is ERC20Votes, AccessControlEnumerable {
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

    address public immutable token;

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
    ) ERC20Votes(_name, _ticker) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        symbioticVault = _symbioticVault;
        symbioticBond = _symbioticBond;
        limit = _limit;
        token = IDefaultBond(symbioticBond).asset();
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

    function setFarm(address rewardToken, address farm) external {
        _requireAdmin();
        _setFarmCallback(rewardToken, farm);
        if (
            rewardToken == token || rewardToken == address(this) || rewardToken == symbioticBond
                || rewardToken == symbioticVault
        ) {
            revert("Vault: forbidden reward token");
        }
        farms[rewardToken] = farm;
    }

    function _setFarmCallback(address rewardToken, address farm) internal virtual {}

    function deposit(address depositToken, uint256 amount, address recipient, address referral) external payable {
        amount = _trimToLimit(address(this), amount);
        amount = _wrap(depositToken, amount);
        push();
        _mint(recipient, amount);
        emit Deposit(recipient, amount, referral);
    }

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
        uint256 amountToClaim = ((wsethBalance + bondBalance + sharesBalance) * amount) / totalSupply();

        uint256 wstEthClaimAmount = amountToClaim > wsethBalance
            ? wsethBalance // @notice The address of the underlying SymbioticBond
            : amountToClaim;
        IERC20(wstETH).safeTransfer(msg.sender, wstEthClaimAmount);
        amountToClaim -= wstEthClaimAmount;

        uint256 bondClaimAmount = amountToClaim > bondBalance ? bondBalance : amountToClaim;
        IDefaultBond(symbioticBond).withdraw(msg.sender, bondClaimAmount);
        amountToClaim -= bondClaimAmount;

        if (amountToClaim == 0) {
            return;
        }

        // @notice The address of the underlying SymbioticBond
        ISymbioticVault(symbioticVault).withdraw(msg.sender, amountToClaim);
        claimEpochs[msg.sender].push(ISymbioticVault(symbioticVault).currentEpoch());
    }

    function claim() external {
        for (uint256 i = 0; i < claimEpochs[msg.sender].length; i++) {
            try ISymbioticVault(symbioticVault).claim(msg.sender, claimEpochs[msg.sender][i]) {
                delete claimEpochs[msg.sender][i];
            } catch {
                continue;
            }
        }
        delete claimEpochs[msg.sender];
    }

    function push() public {
        _pushToSymbioticBond();
        _pushToSymbioticVault();
    }

    function pushRewards(address token) external {
        address farm = farms[token];
        require(farm != address(0), "Vault: farm not set");
        IERC20(token).safeTransfer(farm, IERC20(token).balanceOf(address(this)));
    }

    function _pushToSymbioticVault() internal {
        uint256 bondAmount = IERC20(symbioticBond).balanceOf(address(this));
        IERC20(symbioticBond).safeIncreaseAllowance(symbioticVault, bondAmount);
        (uint256 amount, uint256 shares) = ISymbioticVault(symbioticVault).deposit(address(this), bondAmount);
        emit PushToSymbioticVault(bondAmount, amount, shares);
    }

    function _pushToSymbioticBond() internal {
        uint256 amount = IERC20(wstETH).balanceOf(address(this));
        amount = _trimToLimit(symbioticBond, amount);
        if (amount == 0) {
            return;
        }
        IERC20(wstETH).safeIncreaseAllowance(symbioticBond, amount);
        IDefaultBond(symbioticBond).deposit(address(this), amount);
        emit PushToSymbioticBond(amount);
    }

    function _wrap(address depositToken, uint256 amount) internal virtual {
        if (depositToken != token) ("BaseVault: invalid deposit token");
    }

    function _trimToLimit(address vault, uint256 amount) internal view returns (uint256) {
        uint256 leftover = ILimit(vault).limit() - ILimit(vault).totalSupply();
        return amount > leftover ? leftover : amount;
    }

    function _requireAdmin() internal view {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Vault: must have admin role to set limit");
    }

    event Deposit(address indexed user, uint256 amount, address referral);
    event Withdrawal(address indexed user, uint256 amount);
    event NewLimit(uint256 limit);
    event PushToSymbioticBond(uint256 amount);
    event PushToSymbioticVault(uint256 initialAmount, uint256 amount, uint256 shares);
}
