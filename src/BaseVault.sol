// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import {ERC20VotesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IDefaultCollateral} from "./interfaces/IDefaultCollateral.sol";
import {ISymbioticVault} from "./interfaces/ISymbioticVault.sol";
import {IStakerRewards} from "./interfaces/IStakerRewards.sol";

// TODO:
// 1. Off by 1 errors (add test for MulDiv rounding e.t.c)
// 2. Tests (unit, int, e2e, migration)

/*
    ERC20 Merge Logic:
    Current Symbiotic deployments use ERC20 of oz, while having a few other non-zero slots.
    Slots: https://github.com/mellow-finance/mellow-lrt/blob/main/src/Vault.sol#L12-L28

    The idea is to override all required ERC20Upgradable functions with identical ERC20 functions, by explicitly implementing them in this BaseVault.sol contact.
*/
contract BaseVault is ERC20VotesUpgradeable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // ERC20 slots
    mapping(address account => uint256) private _balances;
    mapping(address account => mapping(address spender => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    // keccak256(abi.encode(uint256(keccak256("mellow.storage.BaseVault")) - 1)) & ~bytes32(uint256(0xff))
    // TODO: FIX THIS
    bytes32 private constant BaseVaultStorageLocation =
        0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef;

    struct FarmData {
        address symbioticFarm;
        address distributionFarm;
        address curatorTreasury;
        uint256 curatorFeeD4;
    }

    struct Storage {
        IDefaultCollateral symbioticCollateral;
        ISymbioticVault symbioticVault;
        address token;
        address owner;
        bool paused;
        uint256 limit;
        EnumerableSet.AddressSet rewardTokens;
        mapping(address rewardToken => FarmData data) farms;
    }

    function _contractStorage() private pure returns (Storage storage $) {
        assembly {
            $.slot := BaseVaultStorageLocation
        }
    }

    function initialize(address _symbioticCollateral, address _symbioticVault, uint256 _limit, address _owner)
        external
        initializer
    {
        __EIP712_init(name(), "1");

        Storage storage s = _contractStorage();
        s.symbioticVault = ISymbioticVault(_symbioticVault);
        s.symbioticCollateral = IDefaultCollateral(_symbioticCollateral);
        s.limit = _limit;
        s.token = IDefaultCollateral(_symbioticCollateral).asset();
        s.owner = _owner;
        s.paused = false;
    }

    function setLimit(uint256 _limit) external onlyOwner {
        Storage storage s = _contractStorage();
        if (totalSupply() > _limit) {
            revert("BaseVault: totalSupply exceeds new limit");
        }
        s.limit = _limit;
        emit NewLimit(_limit);
    }

    function setFarmData(address rewardToken, FarmData memory farmData) external onlyOwner {
        Storage storage s = _contractStorage();
        _setFarmChecks(rewardToken, farmData);
        s.farms[rewardToken] = farmData;
        s.rewardTokens.add(rewardToken);
        emit FarmSet(rewardToken, farmData);
    }

    function removeFarmData(address rewardToken) external onlyOwner {
        Storage storage s = _contractStorage();
        delete s.farms[rewardToken];
        s.rewardTokens.remove(rewardToken);
    }

    function pause() external onlyOwner {
        _contractStorage().paused = true;
    }

    function unpause() external onlyOwner {
        _contractStorage().paused = false;
    }

    function pushRewards(address rewardToken, bytes calldata symbioticRewardsData) external {
        FarmData memory data = _contractStorage().farms[rewardToken];
        require(data.symbioticFarm != address(0), "Vault: farm not set");
        uint256 amountBefore = IERC20(rewardToken).balanceOf(address(this));
        IStakerRewards(data.symbioticFarm).claimRewards(address(this), rewardToken, symbioticRewardsData);
        uint256 rewardAmount = IERC20(rewardToken).balanceOf(address(this)) - amountBefore;
        if (rewardAmount == 0) return;

        uint256 curatorFee = Math.mulDiv(rewardAmount, data.curatorFeeD4, 1e4);
        if (curatorFee != 0) {
            IERC20(rewardToken).safeTransfer(data.curatorTreasury, curatorFee);
            rewardAmount -= curatorFee;
        }

        IERC20(rewardToken).safeTransfer(data.distributionFarm, rewardAmount);
        emit RewardsPushed(rewardToken, rewardAmount, block.timestamp);
    }

    function _setFarmChecks(address rewardToken, FarmData memory farmData) internal virtual {
        Storage storage s = _contractStorage();
        if (
            rewardToken == s.token || rewardToken == address(this) || rewardToken == address(s.symbioticCollateral)
                || rewardToken == address(s.symbioticVault)
        ) {
            revert("Vault: forbidden reward token");
        }
        if (farmData.curatorFeeD4 > 1e4) {
            revert("Vault: invalid curator fee");
        }
    }

    function getSymbioticVaultStake(Math.Rounding rounding) public view returns (uint256 vaultActiveStake) {
        ISymbioticVault symbioticVault = _contractStorage().symbioticVault;
        uint256 vaultActiveShares = symbioticVault.activeSharesOf(address(this));
        uint256 activeStake = symbioticVault.activeStake();
        uint256 activeShares = symbioticVault.activeShares();
        vaultActiveStake = Math.mulDiv(activeStake, vaultActiveShares, activeShares, rounding);
    }

    function tvl(Math.Rounding rounding) public view returns (uint256 totalValueLocked) {
        Storage storage s = _contractStorage();
        return IERC20(s.token).balanceOf(address(this)) + s.symbioticCollateral.balanceOf(address(this))
            + getSymbioticVaultStake(rounding);
    }

    function deposit(address depositToken, uint256 amount, address recipient, address referral) external payable {
        uint256 totalSupply_ = totalSupply();
        uint256 valueBefore = tvl(Math.Rounding.Ceil);
        _deposit(depositToken, amount, referral);
        uint256 valueAfter = tvl(Math.Rounding.Floor);
        if (valueAfter <= valueBefore) {
            revert("BaseVault: invalid deposit amount");
        }
        uint256 depositValue = valueAfter - valueBefore;
        uint256 lpAmount = Math.mulDiv(totalSupply_, depositValue, valueBefore);
        if (lpAmount + totalSupply_ > _contractStorage().limit) {
            revert("BaseVault: vault limit reached");
        } else if (lpAmount == 0) {
            revert("BaseVault: zero lpAmount");
        }
        pushIntoSymbiotic();

        _mint(recipient, lpAmount);
        emit Deposit(recipient, depositValue, lpAmount, referral);
    }

    function withdraw(uint256 lpAmount) external returns (uint256 withdrawnAmount, uint256 amountToClaim) {
        Storage storage s = _contractStorage();
        lpAmount = Math.min(lpAmount, balanceOf(msg.sender));
        if (lpAmount == 0) return (0, 0);
        _burn(msg.sender, lpAmount);

        uint256 tokenValue = IERC20(s.token).balanceOf(address(this));
        uint256 collateralValue = s.symbioticCollateral.balanceOf(address(this));
        uint256 symbioticVaultStake = getSymbioticVaultStake(Math.Rounding.Floor);

        uint256 totalValue = tokenValue + collateralValue + symbioticVaultStake;
        amountToClaim = Math.mulDiv(lpAmount, totalValue, totalSupply());
        if (tokenValue != 0) {
            uint256 tokenAmount = Math.min(amountToClaim, tokenValue);
            IERC20(s.token).safeTransfer(msg.sender, tokenAmount);
            amountToClaim -= tokenAmount;
            withdrawnAmount += tokenAmount;
            if (amountToClaim == 0) return (withdrawnAmount, 0);
        }

        if (collateralValue != 0) {
            uint256 collateralAmount = Math.min(amountToClaim, collateralValue);
            s.symbioticCollateral.withdraw(msg.sender, collateralAmount);

            amountToClaim -= collateralAmount;
            withdrawnAmount += collateralAmount;

            if (amountToClaim == 0) return (withdrawnAmount, 0);
        }

        uint256 sharesAmount = Math.mulDiv(
            amountToClaim, s.symbioticVault.activeShares(), s.symbioticVault.activeStake(), Math.Rounding.Floor
        );

        s.symbioticVault.withdraw(msg.sender, sharesAmount);
    }

    function pushIntoSymbiotic() public {
        Storage storage s = _contractStorage();
        IERC20 token = IERC20(s.token);
        uint256 assetAmount = token.balanceOf(address(this));
        IDefaultCollateral symbioticCollateral = s.symbioticCollateral;
        ISymbioticVault symbioticVault = s.symbioticVault;
        uint256 leftover = symbioticCollateral.limit() - symbioticCollateral.totalSupply();
        assetAmount = Math.min(assetAmount, leftover);
        if (assetAmount == 0) {
            return;
        }
        token.safeIncreaseAllowance(address(symbioticCollateral), assetAmount);
        uint256 amount = symbioticCollateral.deposit(address(this), assetAmount);
        if (amount != assetAmount) {
            token.forceApprove(address(symbioticCollateral), 0);
        }

        uint256 bondAmount = symbioticCollateral.balanceOf(address(this));
        IERC20(symbioticCollateral).safeIncreaseAllowance(address(symbioticVault), bondAmount);
        (uint256 stakedAmount,) = symbioticVault.deposit(address(this), bondAmount);
        if (bondAmount != stakedAmount) {
            IERC20(symbioticCollateral).forceApprove(address(symbioticVault), 0);
        }
    }

    function _deposit(address depositToken, uint256 amount, address /* referral */ ) internal virtual {
        if (depositToken != _contractStorage().token) revert("BaseVault: invalid deposit token");
        IERC20(depositToken).safeTransferFrom(msg.sender, address(this), amount);
    }

    modifier onlyOwner() {
        require(msg.sender == _contractStorage().owner, "BaseVault: forbidden");
        _;
    }

    // ERC20 && ERC20Upgradeable merge
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /// @dev added early revert for paused state
    /// @dev merged ERC20 -> ERC20VotesUpgradeable: in ERC20VotesUpgradeable/ERC20Upgradeable replaces all $ -> direct storage access
    function _update(address from, address to, uint256 value) internal virtual override {
        // ERC20Pausable
        if (_contractStorage().paused) revert("BaseVault: paused");
        // ERC20
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
        // ERC20Votes
        if (from == address(0)) {
            uint256 supply = totalSupply();
            uint256 cap = _maxSupply();
            if (supply > cap) {
                revert ERC20ExceededSafeSupply(supply, cap);
            }
        }
        _transferVotingUnits(from, to, value);
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual override {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    event Deposit(address indexed user, uint256 depositValue, uint256 lpAmount, address referral);
    event NewLimit(uint256 limit);
    event PushToSymbioticBond(uint256 amount);
    event FarmSet(address rewardToken, FarmData farmData);
    event RewardsPushed(address rewardToken, uint256 rewardAmount, uint256 timestamp);
}
